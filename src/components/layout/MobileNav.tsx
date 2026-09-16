import { useState } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import { ChevronDown, Home, Compass, Heart, ShoppingBag, User, X } from "lucide-react";
import { CATEGORIES } from "@/data/taxonomy";
import { PRIMARY_NAV, SHOP_BY_PRICE } from "@/config/navigation";
import { useFocusTrap, useUi } from "@/state/ui";
import { useOguraState } from "@/state/store";
import { Eyebrow } from "@/components/ui-og/primitives";
import { cn } from "@/lib/utils";
import oguraWordmark from "@/assets/ogura-wordmark.png.asset.json";

export function MobileDrawer() {
  const { menuOpen, closeMenu } = useUi();
  const [open, setOpen] = useState<string | null>(null);
  const trapRef = useFocusTrap(menuOpen, closeMenu);
  if (!menuOpen) return null;

  return (
    <div className="fixed inset-0 z-[65] bg-deep lg:hidden" role="dialog" aria-modal="true" aria-label="Menu">
      <div ref={trapRef} className="flex h-full flex-col">
        <div className="flex items-center justify-between border-b border-border px-4 py-4">
          <img src={oguraWordmark.url} alt="OGURA" className="h-5 w-auto" width={820} height={156} decoding="async" />
          <button type="button" onClick={closeMenu} aria-label="Close menu" className="grid size-11 place-items-center">
            <X className="size-5" />
          </button>
        </div>
        <nav aria-label="Mobile" className="flex-1 overflow-y-auto px-4 py-6">
          <ul className="space-y-1">
            {CATEGORIES.map((cat) => (
              <li key={cat.slug} className="border-b border-border">
                <button
                  type="button"
                  aria-expanded={open === cat.slug}
                  onClick={() => setOpen(open === cat.slug ? null : cat.slug)}
                  className="flex min-h-12 w-full items-center justify-between text-left text-sm uppercase tracking-[0.18em]"
                >
                  {cat.name}
                  <ChevronDown className={cn("size-4 transition-transform", open === cat.slug && "rotate-180")} />
                </button>
                {open === cat.slug ? (
                  <ul className="space-y-1 pb-4">
                    <li>
                      <Link
                        to="/women/$categorySlug"
                        params={{ categorySlug: cat.slug }}
                        onClick={closeMenu}
                        className="flex min-h-11 items-center text-sm text-rose"
                      >
                        All {cat.name}
                      </Link>
                    </li>
                    {cat.children.map((child) => (
                      <li key={child.slug}>
                        <Link
                          to="/women/$categorySlug/$subcategorySlug"
                          params={{ categorySlug: cat.slug, subcategorySlug: child.slug }}
                          onClick={closeMenu}
                          className="flex min-h-11 items-center text-sm text-secondary-text"
                        >
                          {child.name}
                        </Link>
                      </li>
                    ))}
                  </ul>
                ) : null}
              </li>
            ))}
          </ul>

          <Eyebrow className="mb-3 mt-8">Discover</Eyebrow>
          <ul>
            {PRIMARY_NAV.filter((n) => n.label !== "SHOP")
              .concat([{ label: "NEW IN", to: "/new-in" }, { label: "LAUNCHPAD", to: "/launchpad" }])
              .map((item) => (
                <li key={item.to}>
                  <Link
                    to={item.to}
                    onClick={closeMenu}
                    className="flex min-h-12 items-center border-b border-border text-sm uppercase tracking-[0.18em]"
                  >
                    {item.label}
                  </Link>
                </li>
              ))}
          </ul>

          <Eyebrow className="mb-3 mt-8">Shop by Price</Eyebrow>
          <ul>
            {SHOP_BY_PRICE.map((item) => (
              <li key={item.to}>
                <Link
                  to={item.to}
                  onClick={closeMenu}
                  className="flex min-h-11 items-center text-sm text-secondary-text"
                >
                  {item.label}
                </Link>
              </li>
            ))}
          </ul>
        </nav>
      </div>
    </div>
  );
}

const ICONS = { Home, Explore: Compass, Wishlist: Heart, Bag: ShoppingBag, Account: User };

export function BottomNav() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const cartCount = useOguraState((s) => s.cart.lines.reduce((n, l) => n + l.quantity, 0));
  if (pathname.startsWith("/checkout") || pathname.startsWith("/order/success")) return null;

  const items = [
    { label: "Home", to: "/" },
    { label: "Explore", to: "/shop" },
    { label: "Wishlist", to: "/wishlist" },
    { label: "Bag", to: "/cart" },
    { label: "Account", to: "/account" },
  ] as const;

  return (
    <nav
      aria-label="Bottom"
      className="fixed inset-x-0 bottom-0 z-40 border-t border-border bg-deep/95 pb-[env(safe-area-inset-bottom)] backdrop-blur lg:hidden"
    >
      <ul className="grid grid-cols-5">
        {items.map((item) => {
          const Icon = ICONS[item.label];
          const active = pathname === item.to;
          return (
            <li key={item.to}>
              <Link
                to={item.to}
                className={cn(
                  "relative flex min-h-14 flex-col items-center justify-center gap-1 text-[10px] uppercase tracking-[0.14em]",
                  active ? "text-foreground" : "text-muted-text",
                )}
              >
                <Icon className="size-5" />
                {item.label}
                {item.label === "Bag" && cartCount ? (
                  <span className="absolute right-5 top-2 grid min-w-4 place-items-center rounded-full bg-rose px-1 text-[9px] leading-4 text-white">
                    {cartCount}
                  </span>
                ) : null}
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
