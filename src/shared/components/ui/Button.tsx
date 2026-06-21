import { forwardRef, type ButtonHTMLAttributes } from "react";
import { cn } from "@/shared/lib/cn";

type Variant = "primary" | "secondary" | "ghost" | "danger";
type Size = "sm" | "md";

const variantClass: Record<Variant, string> = {
  primary:
    "bg-primary text-white shadow-soft hover:bg-primary-hover active:scale-[0.98] disabled:bg-primary/40",
  secondary:
    "border border-light-border-strong bg-light-card text-light-onSurface hover:border-primary/50 hover:bg-primary-soft dark:border-dark-border dark:bg-dark-raised dark:text-dark-onSurface dark:hover:border-primary/50",
  ghost:
    "text-light-onSurface/60 hover:bg-light-onSurface/5 hover:text-light-onSurface dark:text-dark-onSurface/60 dark:hover:bg-white/5 dark:hover:text-dark-onSurface",
  danger:
    "border border-transparent text-red-500 hover:bg-red-500/10",
};

const sizeClass: Record<Size, string> = {
  sm: "h-8 px-3 text-[13px] gap-1.5",
  md: "h-9 px-4 text-sm gap-2",
};

export const Button = forwardRef<
  HTMLButtonElement,
  ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant; size?: Size }
>(({ className, variant = "primary", size = "md", ...props }, ref) => (
  <button
    ref={ref}
    className={cn(
      "inline-flex items-center justify-center rounded-md font-medium transition-all duration-150 disabled:cursor-not-allowed disabled:opacity-50",
      variantClass[variant],
      sizeClass[size],
      className
    )}
    {...props}
  />
));
Button.displayName = "Button";

export const IconButton = forwardRef<
  HTMLButtonElement,
  ButtonHTMLAttributes<HTMLButtonElement> & { active?: boolean }
>(({ className, active, ...props }, ref) => (
  <button
    ref={ref}
    className={cn(
      "inline-flex h-8 w-8 items-center justify-center rounded-md text-light-onSurface/55 transition-colors hover:bg-light-onSurface/8 hover:text-light-onSurface dark:text-dark-onSurface/50 dark:hover:bg-white/8 dark:hover:text-dark-onSurface",
      active && "bg-primary-soft text-primary hover:bg-primary-soft hover:text-primary",
      className
    )}
    {...props}
  />
));
IconButton.displayName = "IconButton";
