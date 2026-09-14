import { createFileRoute, Link } from "@tanstack/react-router";
import { useOguraState } from "@/state/store";
import { formatINR } from "@/lib/format";
import { EmptyState, Eyebrow, OgLinkButton } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/order/success/$orderId")({
  head: () => ({
    meta: [
      { title: "Order placed — OGURA" },
      { name: "description", content: "Your prototype order confirmation on OGURA." },
      { property: "og:title", content: "Order placed — OGURA" },
      { property: "og:description", content: "Prototype order confirmation." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: OrderSuccess,
});

function OrderSuccess() {
  const { orderId } = Route.useParams();
  const order = useOguraState((s) => s.orders.find((o) => o.orderNumber === orderId));

  if (!order) {
    return (
      <div className="og-container py-20">
        <EmptyState
          title="Order not found"
          body="This prototype order isn't stored in this browser."
          action={<OgLinkButton to="/account/orders">View orders</OgLinkButton>}
        />
      </div>
    );
  }

  return (
    <div className="og-container py-14 lg:py-20">
      <div className="mx-auto max-w-2xl">
        <Eyebrow>Confirmed</Eyebrow>
        <h1 className="mt-3 font-display text-4xl">Thank you — your prototype order is placed</h1>
        <p className="mt-3 text-sm text-warning">
          This is a demo order. No payment was taken and nothing will ship.
        </p>

        <div className="mt-8 border border-border p-6">
          <p className="text-[11px] uppercase tracking-[0.18em]">Order number</p>
          <p className="mt-2 font-display text-2xl text-rose">{order.orderNumber}</p>
          <p className="mt-1 text-xs text-muted-text">{new Date(order.createdAt).toLocaleString("en-IN")}</p>

          <ul className="mt-6 space-y-3 text-sm">
            {order.items.map((item) => (
              <li key={item.variantId} className="flex justify-between gap-3">
                <span className="min-w-0 text-secondary-text">
                  {item.title} — {item.size} / {item.color} ×{item.quantity}
                </span>
                <span className="shrink-0">{formatINR(item.price * item.quantity)}</span>
              </li>
            ))}
          </ul>

          <dl className="mt-6 space-y-2 border-t border-border pt-4 text-sm">
            <div className="flex justify-between">
              <dt className="text-secondary-text">Subtotal</dt>
              <dd>{formatINR(order.subtotal)}</dd>
            </div>
            <div className="flex justify-between">
              <dt className="text-secondary-text">Shipping</dt>
              <dd>{order.shipping === 0 ? "Free" : formatINR(order.shipping)}</dd>
            </div>
            <div className="flex justify-between border-t border-border pt-2 text-base">
              <dt>Total</dt>
              <dd>{formatINR(order.total)}</dd>
            </div>
          </dl>

          <div className="mt-6 text-sm text-secondary-text">
            <p className="text-[11px] uppercase tracking-[0.18em] text-foreground">Delivering to</p>
            <p className="mt-2">
              {order.address.fullName}, {order.address.line1} {order.address.line2}, {order.address.city},{" "}
              {order.address.state} {order.address.pincode}
            </p>
          </div>
        </div>

        <div className="mt-8 flex flex-wrap gap-3">
          <OgLinkButton to="/shop">Continue shopping</OgLinkButton>
          <Link
            to="/account/orders"
            className="inline-flex min-h-11 items-center border border-border-strong px-5 text-[11px] uppercase tracking-[0.18em]"
          >
            View all orders
          </Link>
        </div>
      </div>
    </div>
  );
}
