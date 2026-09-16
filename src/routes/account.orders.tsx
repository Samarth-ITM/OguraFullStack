import { createFileRoute, Link } from "@tanstack/react-router";
import { useOguraState } from "@/state/store";
import { formatINR } from "@/lib/format";
import { EmptyState, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/account/orders")({
  head: () => ({
    meta: [
      { title: "My orders — OGURA" },
      { name: "description", content: "Prototype orders placed in this browser." },
      { property: "og:title", content: "My orders — OGURA" },
      { property: "og:description", content: "Prototype orders placed in this browser." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: OrdersPage,
});

function OrdersPage() {
  const orders = useOguraState((s) => s.orders);

  if (orders.length === 0) {
    return (
      <EmptyState
        title="No orders yet"
        body="Prototype orders you place will be listed here."
        action={<OgLinkButton to="/shop">Start shopping</OgLinkButton>}
      />
    );
  }

  return (
    <ul className="space-y-5">
      {orders.map((order) => (
        <li key={order.orderNumber} className="border border-border p-6">
          <div className="grid grid-cols-[minmax(0,1fr)_auto] items-start gap-4">
            <div className="min-w-0">
              <p className="truncate font-display text-xl">{order.orderNumber}</p>
              <p className="mt-1 text-xs text-muted-text">
                {new Date(order.createdAt).toLocaleDateString("en-IN")} · {order.items.length} item(s)
              </p>
            </div>
            <span className="shrink-0 border border-border px-3 py-1 text-[10px] uppercase tracking-[0.16em] capitalize">
              {order.status}
            </span>
          </div>
          <p className="mt-4 text-sm text-secondary-text">
            {order.items.map((i) => i.title).join(", ")}
          </p>
          <div className="mt-4 flex flex-wrap items-center justify-between gap-3">
            <span className="text-sm">{formatINR(order.total)}</span>
            <Link
              to="/order/success/$orderId"
              params={{ orderId: order.orderNumber }}
              className="text-[11px] uppercase tracking-[0.18em] text-rose"
            >
              View details
            </Link>
          </div>
        </li>
      ))}
    </ul>
  );
}
