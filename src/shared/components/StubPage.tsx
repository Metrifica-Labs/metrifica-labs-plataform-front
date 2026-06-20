export function StubPage({ title }: { title: string }) {
  return (
    <div className="flex h-full items-center justify-center text-light-onSurface/60 dark:text-white/40">
      <p>{title} — em construção</p>
    </div>
  );
}
