import { Outlet, createFileRoute, Link } from "@tanstack/react-router";
import { Eyebrow, PrototypeTag } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/seller")({
  component: SellerLayout,
});

const LINKS = [
  { to: "/seller", label: "Dashboard" },
  { to: "/seller/products", label: "Products" },
  { to: "/seller/orders", label: "Orders" },
  { to: "/seller/payouts", label: "Payouts" },
] as const;

function SellerLayout() {
  return (
    <div className="og-container py-10 lg:py-16">
      <div className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4">
        <div className="min-w-0">
          <Eyebrow>Seller studio</Eyebrow>
          <h1 className="mt-2 truncate font-display text-4xl">Designer workspace</h1>
        </div>
        <PrototypeTag />
      </div>
      <p className="mt-3 text-sm text-warning">
        Read-only prototype shell — figures are mock data and nothing can be published.
      </p>

      <div className="mt-8 grid gap-10 lg:grid-cols-[200px_minmax(0,1fr)]">
        <nav aria-label="Seller" className="flex gap-4 overflow-x-auto lg:flex-col lg:gap-2">
          {LINKS.map((link) => (
            <Link
              key={link.to}
              to={link.to}
              activeOptions={{ exact: link.to === "/seller" }}
              activeProps={{ className: "text-rose" }}
              inactiveProps={{ className: "text-secondary-text" }}
              className="shrink-0 py-1 text-[11px] uppercase tracking-[0.18em]"
            >
              {link.label}
            </Link>
          ))}
        </nav>
        <div className="min-w-0">
          <Outlet />
        </div>
      </div>
    </div>
  );
}
