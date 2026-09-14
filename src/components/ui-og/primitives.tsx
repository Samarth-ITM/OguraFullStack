import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, Ref } from "react";
import { Link } from "@tanstack/react-router";
import { cn } from "@/lib/utils";

type Variant = "primary" | "secondary" | "ghost" | "quiet";

const BASE =
  "inline-flex min-h-11 items-center justify-center gap-2 rounded-[3px] px-5 text-[11px] font-medium uppercase tracking-[0.18em] transition-colors duration-200 disabled:cursor-not-allowed disabled:opacity-45";

const VARIANTS: Record<Variant, string> = {
  primary: "bg-rose text-white hover:bg-rose-hover active:bg-rose-active",
  secondary: "border border-border-strong bg-transparent text-foreground hover:bg-hover",
  ghost: "text-foreground hover:text-rose",
  quiet: "border border-border bg-surface text-secondary-text hover:bg-hover hover:text-foreground",
};

export function OgButton({
  variant = "primary",
  className,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  return <button {...props} className={cn(BASE, VARIANTS[variant], className)} />;
}

export function OgLinkButton({
  to,
  variant = "primary",
  className,
  children,
  search,
  onClick,
}: {
  to: string;
  variant?: Variant;
  className?: string;
  children: ReactNode;
  search?: Record<string, unknown>;
  onClick?: () => void;
}) {
  return (
    <Link
      to={to}
      search={search as never}
      onClick={onClick}
      className={cn(BASE, VARIANTS[variant], className)}
    >
      {children}
    </Link>
  );
}

export function OgInput({
  className,
  ...props
}: InputHTMLAttributes<HTMLInputElement> & { ref?: Ref<HTMLInputElement> }) {
  return (
    <input
      {...props}
      className={cn(
        "min-h-11 w-full rounded-[5px] border border-border bg-surface px-3 text-sm text-foreground placeholder:text-muted-text focus:border-border-strong focus:outline-none",
        className,
      )}
    />
  );
}

export function Eyebrow({ children, className }: { children: ReactNode; className?: string }) {
  return <p className={cn("eyebrow", className)}>{children}</p>;
}

export function SectionHeading({
  eyebrow,
  title,
  description,
  action,
  as: Tag = "h2",
}: {
  eyebrow?: string;
  title: string;
  description?: string;
  action?: ReactNode;
  as?: "h1" | "h2";
}) {
  return (
    <div className="grid grid-cols-[minmax(0,1fr)_auto] items-end gap-4 sm:flex sm:flex-wrap sm:justify-between">
      <div className="min-w-0">
        {eyebrow ? <Eyebrow className="mb-3">{eyebrow}</Eyebrow> : null}
        <Tag className="display-h2 text-foreground">{title}</Tag>
        {description ? (
          <p className="mt-3 max-w-xl text-sm text-secondary-text">{description}</p>
        ) : null}
      </div>
      {action ? <div className="shrink-0">{action}</div> : null}
    </div>
  );
}

export function PrototypeTag({ className }: { className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-[3px] border border-border-strong bg-raised px-2 py-1 text-[10px] uppercase tracking-[0.18em] text-secondary-text",
        className,
      )}
    >
      Prototype
    </span>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn("animate-pulse bg-raised", className)} aria-hidden />;
}

export function EmptyState({
  title,
  body,
  action,
}: {
  title: string;
  body: string;
  action?: ReactNode;
}) {
  return (
    <div className="border border-border bg-surface px-6 py-16 text-center">
      <h3 className="font-display text-2xl text-foreground">{title}</h3>
      <p className="mx-auto mt-3 max-w-md text-sm text-secondary-text">{body}</p>
      {action ? <div className="mt-6 flex flex-wrap justify-center gap-3">{action}</div> : null}
    </div>
  );
}
