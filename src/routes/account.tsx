import { Outlet, createFileRoute, Link } from "@tanstack/react-router";
import { Eyebrow } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/account")({
  component: AccountLayout,
});

const LINKS = [
  { to: "/account", label: "Overview", exact: true },
  { to: "/account/orders", label: "Orders" },
  { to: "/account/wishlist", label: "Wishlist" },
  { to: "/account/addresses", label: "Addresses" },
  { to: "/account/profile", label: "Profile" },
] as const;

function AccountLayout() {
  return (
    <div className="og-container py-10 lg:py-16">
      <Eyebrow>Account</Eyebrow>
      <h1 className="mt-2 font-display text-4xl">My OGURA</h1>

      <div className="mt-8 grid gap-10 lg:grid-cols-[220px_minmax(0,1fr)]">
        <nav aria-label="Account" className="flex gap-4 overflow-x-auto lg:flex-col lg:gap-2">
          {LINKS.map((link) => (
            <Link
              key={link.to}
              to={link.to}
              activeOptions={{ exact: "exact" in link }}
              activeProps={{ className: "text-rose" }}
              inactiveProps={{ className: "text-secondary-text" }}
              className="shrink-0 py-1 text-[11px] uppercase tracking-[0.18em] hover:text-foreground"
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
