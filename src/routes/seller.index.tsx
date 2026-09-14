import { createFileRoute } from "@tanstack/react-router";
import { allProducts } from "@/repositories/mock/catalog";
import { formatINR } from "@/lib/format";

export const Route = createFileRoute("/seller/")({
  head: () => ({
    meta: [
      { title: "Seller dashboard — OGURA" },
      { name: "description", content: "Mock seller dashboard for the OGURA prototype." },
      { property: "og:title", content: "Seller dashboard — OGURA" },
      { property: "og:description", content: "Mock seller dashboard metrics." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SellerDashboard,
});

function SellerDashboard() {
  const mine = allProducts.slice(0, 18);
  const stats = [
    { label: "Live styles", value: String(mine.length) },
    { label: "Mock GMV (30d)", value: formatINR(486000) },
    { label: "Orders (30d)", value: "132" },
    { label: "Avg. rating", value: "4.4" },
  ];

  return (
    <div className="space-y-10">
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {stats.map((s) => (
          <div key={s.label} className="border border-border p-5">
            <p className="text-[11px] uppercase tracking-[0.18em] text-muted-text">{s.label}</p>
            <p className="mt-2 font-display text-2xl">{s.value}</p>
          </div>
        ))}
      </div>

      <div>
        <h2 className="text-[11px] uppercase tracking-[0.18em]">Recent activity (mock)</h2>
        <ul className="mt-4 space-y-3 text-sm text-secondary-text">
          <li>Order DEMO-OG-4821 packed · 2 items</li>
          <li>Style “{mine[0]?.title}” viewed 214 times this week</li>
          <li>Payout of {formatINR(64200)} scheduled for the 15th</li>
        </ul>
      </div>
    </div>
  );
}
