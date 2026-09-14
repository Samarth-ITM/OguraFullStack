import { Link } from "@tanstack/react-router";
import { EditorialBannerPlaceholder } from "@/components/media/slots";
import { Eyebrow } from "@/components/ui-og/primitives";

export function EditorialInsert({
  slotId,
  eyebrow,
  title,
  body,
  cta,
  to,
}: {
  slotId: string;
  eyebrow: string;
  title: string;
  body: string;
  cta: string;
  to: string;
}) {
  return (
    <section className="col-span-full my-4 grid items-center gap-6 border border-border bg-surface p-4 md:grid-cols-[1.4fr_1fr] md:p-6">
      <EditorialBannerPlaceholder slotId={slotId} alt={title} label={`INSERT · ${slotId}`} />
      <div>
        <Eyebrow>{eyebrow}</Eyebrow>
        <h3 className="mt-3 font-display text-3xl leading-tight">{title}</h3>
        <p className="mt-3 text-sm text-secondary-text">{body}</p>
        <Link to={to} className="mt-5 inline-block text-[11px] uppercase tracking-[0.18em] text-rose hover:text-rose-hover">
          {cta} →
        </Link>
      </div>
    </section>
  );
}
