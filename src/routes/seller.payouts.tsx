import { createFileRoute } from "@tanstack/react-router";
import { formatINR } from "@/lib/format";

export const Route = createFileRoute("/seller/payouts")({
  head: () => ({
    meta: [
      { title: "Seller payouts — OGURA" },
      { name: "description", content: "Mock payout schedule for the OGURA seller prototype." },
      { property: "og:title", content: "Seller payouts — OGURA" },
      { property: "og:description", content: "Mock payout schedule." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SellerPayouts,
});

const PAYOUTS = [
  { cycle: "1–15 Aug", amount: 64200, status: "Paid" },
  { cycle: "16–31 Aug", amount: 81450, status: "Paid" },
  { cycle: "1–15 Sep", amount: 57900, status: "Scheduled" },
];

function SellerPayouts() {
  return (
    <div className="space-y-4">
      {PAYOUTS.map((p) => (
        <div key={p.cycle} className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4 border border-border p-5">
          <div className="min-w-0">
            <p className="text-sm">{p.cycle}</p>
            <p className="text-xs text-muted-text">Mock cycle</p>
          </div>
          <div className="shrink-0 text-right">
            <p className="font-display text-xl">{formatINR(p.amount)}</p>
            <p className="text-[10px] uppercase tracking-[0.16em] text-secondary-text">{p.status}</p>
          </div>
        </div>
      ))}
    </div>
  );
}
