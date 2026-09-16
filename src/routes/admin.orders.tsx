import { createFileRoute } from "@tanstack/react-router";
import { useOguraState } from "@/state/store";
import { formatINR } from "@/lib/format";
import { EmptyState } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/admin/orders")({
  head: () => ({
    meta: [
      { title: "Admin orders — OGURA" },
      { name: "description", content: "Prototype orders recorded in this browser." },
      { property: "og:title", content: "Admin orders — OGURA" },
      { property: "og:description", content: "Prototype order log." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AdminOrders,
});

function AdminOrders() {
  const orders = useOguraState((s) => s.orders);

  if (orders.length === 0) {
    return <EmptyState title="No prototype orders" body="Place a demo order in checkout to see it listed here." />;
  }

  return (
    <ul className="space-y-3">
      {orders.map((o) => (
        <li key={o.orderNumber} className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4 border border-border p-4">
          <div className="min-w-0">
            <p className="truncate text-sm">{o.orderNumber}</p>
            <p className="text-xs text-secondary-text">
              {o.address.city || "—"} · {o.items.length} item(s)
            </p>
          </div>
          <div className="shrink-0 text-right">
            <p className="text-sm">{formatINR(o.total)}</p>
            <p className="text-[10px] uppercase tracking-[0.16em] text-muted-text capitalize">{o.status}</p>
          </div>
        </li>
      ))}
    </ul>
  );
}
