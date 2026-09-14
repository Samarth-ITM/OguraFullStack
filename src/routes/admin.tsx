import { Outlet, createFileRoute, Link } from "@tanstack/react-router";
import { Eyebrow, PrototypeTag } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/admin")({
  component: AdminLayout,
});

const LINKS = [
  { to: "/admin", label: "Overview" },
  { to: "/admin/catalog", label: "Catalog" },
  { to: "/admin/merchandising", label: "Merchandising" },
  { to: "/admin/orders", label: "Orders" },
] as const;

function AdminLayout() {
  return (
    <div className="og-container py-10 lg:py-16">
      <div className="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-4">
        <div className="min-w-0">
          <Eyebrow>Admin</Eyebrow>
          <h1 className="mt-2 truncate font-display text-4xl">Operations console</h1>
        </div>
        <PrototypeTag />
      </div>
      <p className="mt-3 text-sm text-warning">Read-only prototype shell with mock data.</p>

      <div className="mt-8 grid gap-10 lg:grid-cols-[220px_minmax(0,1fr)]">
        <nav aria-label="Admin" className="flex gap-4 overflow-x-auto lg:flex-col lg:gap-2">
          {LINKS.map((link) => (
            <Link
              key={link.to}
              to={link.to}
              activeOptions={{ exact: link.to === "/admin" }}
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
