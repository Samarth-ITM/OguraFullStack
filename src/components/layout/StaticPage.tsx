import type { ReactNode } from "react";
import { Eyebrow, PrototypeTag } from "@/components/ui-og/primitives";

export interface StaticSection {
  heading: string;
  body: string;
}

export function StaticPage({
  eyebrow,
  title,
  intro,
  sections,
  children,
}: {
  eyebrow: string;
  title: string;
  intro: string;
  sections: StaticSection[];
  children?: ReactNode;
}) {
  return (
    <div className="og-container py-12 lg:py-20">
      <div className="mx-auto max-w-3xl">
        <div className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-4">
          <div className="min-w-0">
            <Eyebrow>{eyebrow}</Eyebrow>
            <h1 className="mt-3 font-display text-4xl lg:text-5xl">{title}</h1>
          </div>
          <PrototypeTag />
        </div>
        <p className="mt-5 text-sm leading-relaxed text-secondary-text">{intro}</p>

        <div className="mt-10 space-y-8">
          {sections.map((section) => (
            <section key={section.heading}>
              <h2 className="text-[11px] uppercase tracking-[0.18em]">{section.heading}</h2>
              <p className="mt-3 text-sm leading-relaxed text-secondary-text">{section.body}</p>
            </section>
          ))}
        </div>

        {children}

        <p className="mt-12 border-t border-border pt-6 text-xs text-muted-text">
          Placeholder copy for a design prototype. Nothing on this page is a real policy or commitment.
        </p>
      </div>
    </div>
  );
}
