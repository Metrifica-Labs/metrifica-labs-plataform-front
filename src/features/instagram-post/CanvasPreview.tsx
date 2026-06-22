import { PostCanvas } from "@/features/instagram-post/PostCanvas";
import { PostCanvasType2 } from "@/features/instagram-post/PostCanvasType2";
import { PostCanvasType3 } from "@/features/instagram-post/PostCanvasType3";
import { PostCanvasType4 } from "@/features/instagram-post/PostCanvasType4";
import type { useInstagramPost } from "@/features/instagram-post/useInstagramPost";
import type { SlideLayout } from "@/features/instagram-post/instagram-post-style";

type Post = ReturnType<typeof useInstagramPost>;

/**
 * Thin wrapper that delegates to the correct PostCanvas* renderer for a given
 * layout. The PostCanvas* components own all pixel output and are intentionally
 * left untouched — this component only routes to them.
 */
function CanvasFor({
  layout,
  ...props
}: {
  layout: SlideLayout;
  style: Post["style"];
  slide: Post["style"]["slides"][number];
  index: number;
  total: number;
  innerRef?: React.Ref<HTMLDivElement>;
}) {
  switch (layout) {
    case "imageCover":
      return <PostCanvasType2 {...props} />;
    case "textGrid":
      return <PostCanvasType3 {...props} />;
    case "imageStack":
      return <PostCanvasType4 {...props} />;
    default:
      return <PostCanvas {...props} />;
  }
}

export function CanvasPreview({
  style,
  slide,
  index,
  total,
  innerRef,
}: {
  style: Post["style"];
  slide: Post["style"]["slides"][number] | undefined;
  index: number;
  total: number;
  innerRef: React.Ref<HTMLDivElement>;
}) {
  return (
    <div className="mb-4 flex items-center justify-center rounded-xl bg-light-onSurface/5 p-6 dark:bg-white/5">
      {slide ? (
        <CanvasFor
          layout={slide.layout}
          style={style}
          slide={slide}
          index={index}
          total={total}
          innerRef={innerRef}
        />
      ) : (
        <div className="flex h-[480px] w-full max-w-[380px] items-center justify-center rounded-xl border border-dashed border-light-border text-center text-[13px] text-light-onSurface/35 dark:border-dark-border dark:text-white/30">
          O preview aparece após gerar o conteúdo.
        </div>
      )}
    </div>
  );
}
