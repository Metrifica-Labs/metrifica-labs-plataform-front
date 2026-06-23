import { useRef, useState } from "react";
import { useAuthStore } from "@/core/auth/auth-store";
import {
  uploadSlidesToBucket,
  publishInstagramPost,
  scheduleInstagramPost,
} from "@/features/instagram-post/instagram-publish";

export type PublishState = "idle" | "uploading" | "publishing" | "done" | "error";

export function useInstagramPublish(slideCount: number) {
  const userId = useAuthStore((s) => s.user?.id);
  const slideRefs = useRef<(HTMLDivElement | null)[]>([]);
  const [state, setState] = useState<PublishState>("idle");
  const [error, setError] = useState<string | null>(null);

  function setRef(index: number) {
    return (el: HTMLDivElement | null) => {
      slideRefs.current[index] = el;
    };
  }

  function validNodes(): HTMLDivElement[] {
    return slideRefs.current.slice(0, slideCount).filter(Boolean) as HTMLDivElement[];
  }

  async function publish() {
    if (!userId) return;
    const nodes = validNodes();
    if (nodes.length === 0) return;

    try {
      setError(null);
      setState("uploading");
      const paths = await uploadSlidesToBucket(nodes, userId);
      setState("publishing");
      await publishInstagramPost(paths);
      setState("done");
      setTimeout(() => setState("idle"), 4000);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setState("error");
    }
  }

  async function schedule(scheduledAt: Date) {
    if (!userId) return;
    const nodes = validNodes();
    if (nodes.length === 0) return;

    try {
      setError(null);
      setState("uploading");
      const paths = await uploadSlidesToBucket(nodes, userId);
      setState("publishing");
      await scheduleInstagramPost(paths, scheduledAt);
      setState("done");
      setTimeout(() => setState("idle"), 4000);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setState("error");
    }
  }

  function reset() {
    setState("idle");
    setError(null);
  }

  const isWorking = state === "uploading" || state === "publishing";

  return { state, error, isWorking, slideCount, setRef, publish, schedule, reset, getNodes: validNodes };
}
