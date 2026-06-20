import { describe, it, expect, vi, afterEach } from "vitest";
import { streamSSE, edgeFunctionUrl } from "@/core/sse/sse-client";
import { env } from "@/core/env";

function streamFromChunks(chunks: string[]): ReadableStream<Uint8Array> {
  const encoder = new TextEncoder();
  let i = 0;
  return new ReadableStream({
    pull(controller) {
      if (i < chunks.length) {
        controller.enqueue(encoder.encode(chunks[i++]));
      } else {
        controller.close();
      }
    },
  });
}

function mockFetchOk(chunks: string[]) {
  return vi.fn().mockResolvedValue(
    new Response(streamFromChunks(chunks), { status: 200 })
  );
}

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("edgeFunctionUrl", () => {
  it("builds the supabase functions URL", () => {
    expect(edgeFunctionUrl("run-flow")).toBe(`${env.supabaseUrl}/functions/v1/run-flow`);
  });
});

describe("streamSSE", () => {
  it("parses complete data lines and stops on [DONE]", async () => {
    vi.stubGlobal(
      "fetch",
      mockFetchOk([
        'data: {"type":"text","text":"Hello"}\n',
        'data: {"type":"text","text":" world"}\n',
        "data: [DONE]\n",
      ])
    );

    const events: unknown[] = [];
    await streamSSE("https://example.test", {}, (e) => {
      events.push(e);
    });

    expect(events).toEqual([
      { type: "text", text: "Hello" },
      { type: "text", text: " world" },
    ]);
  });

  it("reassembles a JSON payload split across chunk boundaries", async () => {
    vi.stubGlobal(
      "fetch",
      mockFetchOk(['data: {"type":"text",', '"text":"chunked"}\n', "data: [DONE]\n"])
    );

    const events: unknown[] = [];
    await streamSSE("https://example.test", {}, (e) => {
      events.push(e);
    });

    expect(events).toEqual([{ type: "text", text: "chunked" }]);
  });

  it("ignores malformed lines instead of throwing", async () => {
    vi.stubGlobal(
      "fetch",
      mockFetchOk(["data: not-json\n", 'data: {"type":"text","text":"ok"}\n', "data: [DONE]\n"])
    );

    const events: unknown[] = [];
    await streamSSE("https://example.test", {}, (e) => {
      events.push(e);
    });

    expect(events).toEqual([{ type: "text", text: "ok" }]);
  });

  it("stops early when onEvent returns true", async () => {
    vi.stubGlobal(
      "fetch",
      mockFetchOk([
        'data: {"type":"error","message":"boom"}\n',
        'data: {"type":"text","text":"should not appear"}\n',
        "data: [DONE]\n",
      ])
    );

    const events: unknown[] = [];
    await streamSSE("https://example.test", {}, (e) => {
      events.push(e);
      return e.type === "error";
    });

    expect(events).toEqual([{ type: "error", message: "boom" }]);
  });

  it("throws with the response body when the request fails", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(new Response("server exploded", { status: 500 }))
    );

    await expect(streamSSE("https://example.test", {}, () => {})).rejects.toThrow(
      /Erro 500: server exploded/
    );
  });
});
