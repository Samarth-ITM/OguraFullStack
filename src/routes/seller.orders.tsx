import { createFileRoute } from "@tanstack/react-router";
import { allProducts } from "@/repositories/mock/catalog";
import { formatINR } from "@/lib/format";

export const Route = createFileRoute("/seller/orders")({
  head: () => ({
    meta: [
      { title: "Seller orders — OGURA" },
      { name: "description", content: "Mock order queue for the OGURA seller prototype." },
      { property: "og:title", content: "Seller orders — OGURA" },
      { property: "og:description", content: "Mock seller order queue." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SellerOrders,
});

const STATUSES = ["placed", "packed", "shipped", "delivered"] as const;

function SellerOrders() {
  const rows = allProducts.slice(30, 42).map((p, i) => ({
    id: `DEMO-OG-${5000 + i}`,
    title: p.title,
    total: p.price,
    status: STATUSES[i % STATUSES.length],
  }));

  return (
    <ul className="space-y-3">
      {rows.map((row) => (
        <li key={row.id} className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4 border border-border p-4">
          <div className="min-w-0">
            <p className="text-sm">{row.id}</p>
            <p className="truncate text-xs text-secondary-text">{row.title}</p>
          </div>
          <div className="shrink-0 text-right">
            <p className="text-sm">{formatINR(row.total)}</p>
            <p className="text-[10px] uppercase tracking-[0.16em] text-muted-text">{row.status}</p>
          </div>
        </li>
      ))}
    </ul>
  );
}
