import { useRef } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import type { Product } from "@/domain/catalog";
import { ProductCard } from "./ProductCard";

export function ProductRail({
  products,
  perView = 4,
  ariaLabel,
}: {
  products: Product[];
  perView?: 4 | 5;
  ariaLabel: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  if (!products.length) return null;

  const scrollBy = (dir: 1 | -1) => {
    const node = ref.current;
    if (!node) return;
    node.scrollBy({ left: dir * node.clientWidth * 0.8, behavior: "smooth" });
  };

  return (
    <div className="relative">
      <div className="mb-4 hidden justify-end gap-2 lg:flex">
        <button
          type="button"
          onClick={() => scrollBy(-1)}
          aria-label="Scroll left"
          className="grid size-11 place-items-center border border-border text-secondary-text hover:text-foreground"
        >
          <ChevronLeft className="size-4" />
        </button>
        <button
          type="button"
          onClick={() => scrollBy(1)}
          aria-label="Scroll right"
          className="grid size-11 place-items-center border border-border text-secondary-text hover:text-foreground"
        >
          <ChevronRight className="size-4" />
        </button>
      </div>
      <div
        ref={ref}
        role="region"
        aria-label={ariaLabel}
        tabIndex={0}
        className="og-rail gap-4 pb-2"
        style={{
          gridAutoColumns: `calc((100% - 1rem) / 2.15)`,
        }}
      >
        {products.map((p) => (
          <div key={p.id} className={perView === 5 ? "lg:!w-auto" : "lg:!w-auto"}>
            <ProductCard product={p} />
          </div>
        ))}
      </div>
      <style>{`
        @media (min-width: 1024px) {
          [aria-label="${ariaLabel}"] { grid-auto-columns: calc((100% - ${(perView - 1) * 1}rem) / ${perView}) !important; }
        }
      `}</style>
    </div>
  );
}
