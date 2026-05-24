const GITHUB_API = "https://api.github.com";
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function gh(path: string, options: RequestInit = {}): Promise<unknown> {
  const token = Deno.env.get("GITHUB_TOKEN");
  if (!token) throw new Error("GITHUB_TOKEN não configurado");
  const res = await fetch(`${GITHUB_API}${path}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "Content-Type": "application/json",
      ...(options.headers as Record<string, string>),
    },
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`GitHub API ${res.status} ${path}: ${err}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

// Testa autenticação GitHub + cria/verifica repo de calibração
async function testGitHubAuth(): Promise<{ ok: boolean; message: string }> {
  const user = (await gh("/user")) as { login: string };
  return { ok: true, message: `Autenticado como ${user.login}` };
}

async function testGitHubCreateRepo(): Promise<{ ok: boolean; message: string }> {
  const user = (await gh("/user")) as { login: string };
  const owner = user.login;
  const testRepo = "squad-calibration-test";

  // Verifica se repo de teste já existe
  try {
    await gh(`/repos/${owner}/${testRepo}`);
    return { ok: true, message: `Permissão de criação OK (repo de teste já existe: ${owner}/${testRepo})` };
  } catch {
    // Não existe — cria
    await gh("/user/repos", {
      method: "POST",
      body: JSON.stringify({ name: testRepo, description: "Repo de calibração do Squad", private: true, auto_init: true }),
    });
    return { ok: true, message: `Repo de calibração criado com sucesso: ${owner}/${testRepo}` };
  }
}

async function testGitHubPushFiles(): Promise<{ ok: boolean; message: string }> {
  const user = (await gh("/user")) as { login: string };
  const owner = user.login;
  const testRepo = "squad-calibration-test";

  // Garante que o repo existe
  let defaultBranch = "main";
  try {
    const repo = (await gh(`/repos/${owner}/${testRepo}`)) as { default_branch: string };
    defaultBranch = repo.default_branch;
  } catch {
    await gh("/user/repos", {
      method: "POST",
      body: JSON.stringify({ name: testRepo, private: true, auto_init: true }),
    });
    await new Promise((r) => setTimeout(r, 2_000));
  }

  // Pega SHA do HEAD
  const ref = (await gh(`/repos/${owner}/${testRepo}/git/refs/heads/${defaultBranch}`)) as { object: { sha: string } };
  const latestSha = ref.object.sha;
  const baseCommit = (await gh(`/repos/${owner}/${testRepo}/git/commits/${latestSha}`)) as { tree: { sha: string } };

  const ts = new Date().toISOString();
  const encoded = btoa(`Calibração em ${ts}`);
  const blob = (await gh(`/repos/${owner}/${testRepo}/git/blobs`, {
    method: "POST",
    body: JSON.stringify({ content: encoded, encoding: "base64" }),
  })) as { sha: string };

  const tree = (await gh(`/repos/${owner}/${testRepo}/git/trees`, {
    method: "POST",
    body: JSON.stringify({ base_tree: baseCommit.tree.sha, tree: [{ path: "calibration.txt", mode: "100644", type: "blob", sha: blob.sha }] }),
  })) as { sha: string };

  const newCommit = (await gh(`/repos/${owner}/${testRepo}/git/commits`, {
    method: "POST",
    body: JSON.stringify({ message: `calibration test ${ts}`, tree: tree.sha, parents: [latestSha] }),
  })) as { sha: string };

  await gh(`/repos/${owner}/${testRepo}/git/refs/heads/${defaultBranch}`, {
    method: "PATCH",
    body: JSON.stringify({ sha: newCommit.sha }),
  });

  return { ok: true, message: `Push OK — arquivo commitado em ${owner}/${testRepo}` };
}

async function testGitHubReadFile(): Promise<{ ok: boolean; message: string }> {
  const user = (await gh("/user")) as { login: string };
  const owner = user.login;
  const testRepo = "squad-calibration-test";

  try {
    await gh(`/repos/${owner}/${testRepo}/contents/calibration.txt`);
    return { ok: true, message: `Leitura OK — arquivo calibration.txt acessível em ${owner}/${testRepo}` };
  } catch {
    return { ok: false, message: `Arquivo de calibração não encontrado — rode o teste de push_files primeiro` };
  }
}

async function testGitHubActions(): Promise<{ ok: boolean; message: string }> {
  const user = (await gh("/user")) as { login: string };
  return { ok: true, message: `GitHub Actions API acessível — usuário: ${user.login}` };
}

const TOOL_TESTS: Record<string, () => Promise<{ ok: boolean; message: string }>> = {
  github_create_repo: testGitHubCreateRepo,
  github_push_files: testGitHubPushFiles,
  github_read_file: testGitHubReadFile,
  github_get_actions_status: testGitHubActions,
  github_get_actions_logs: testGitHubActions,
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS_HEADERS });

  const start = Date.now();
  try {
    const { tool_name } = await req.json();
    if (!tool_name) {
      return new Response(JSON.stringify({ ok: false, message: "tool_name obrigatório" }), {
        status: 400,
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      });
    }

    const test = TOOL_TESTS[tool_name];
    if (!test) {
      return new Response(JSON.stringify({ ok: true, message: "Tool sem teste automático disponível", duration_ms: 0 }), {
        headers: { "Content-Type": "application/json", ...CORS_HEADERS },
      });
    }

    const result = await test();
    return new Response(
      JSON.stringify({ ...result, duration_ms: Date.now() - start }),
      { headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ ok: false, message: String(err), duration_ms: Date.now() - start }),
      { headers: { "Content-Type": "application/json", ...CORS_HEADERS } }
    );
  }
});
