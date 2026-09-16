import { useEffect, useRef, useState } from "react";
import { Link, useRouterState } from "@tanstack/react-router";
import { Heart, Menu, Search, ShoppingBag, User } from "lucide-react";
import { PRIMARY_NAV, SHOP_BY_PRICE } from "@/config/navigation";
import { CATEGORIES } from "@/data/taxonomy";
import { useUi } from "@/state/ui";
import { useOguraState } from "@/state/store";
import { Eyebrow } from "@/components/ui-og/primitives";
import { CategoryTilePlaceholder } from "@/components/media/slots";
import { cn } from "@/lib/utils";
import oguraWordmark from "@/assets/ogura-wordmark.png.asset.json";

export function Header() {
  const { openSearch, openCart, openMenu } = useUi();
  const [scrolled, setScrolled] = useState(false);
  const [megaOpen, setMegaOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const isHome = pathname === "/";
  const cartCount = useOguraState((s) => s.cart.lines.reduce((n, l) => n + l.quantity, 0));
  const wishCount = useOguraState((s) => s.wishlist.length);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  useEffect(() => {
    setMegaOpen(false);
  }, [pathname]);

  const solid = scrolled || !isHome || megaOpen;

  return (
    <header
      className={cn(
        "fixed inset-x-0 top-0 z-50 transition-colors duration-200",
        solid ? "border-b border-border bg-deep/95 backdrop-blur" : "bg-transparent",
      )}
      onMouseLeave={() => setMegaOpen(false)}
    >
      <div className="container-og flex h-[68px] items-center justify-between gap-4 lg:h-20">
        <div className="flex items-center gap-3 lg:hidden">
          <button type="button" onClick={openMenu} aria-label="Open menu" className="grid size-11 place-items-center">
            <Menu className="size-5" />
          </button>
        </div>

        <Link to="/" className="flex items-center" aria-label="OGURA home">
          <img
            src={oguraWordmark.url}
            alt="OGURA"
            className="h-6 w-auto lg:h-7"
            width={820}
            height={156}
            decoding="async"
          />
        </Link>

        <nav aria-label="Primary" className="hidden lg:block">
          <ul className="flex items-center gap-8">
            {PRIMARY_NAV.map((item) =>
              item.label === "SHOP" ? (
                <li key={item.label}>
                  <button
                    ref={triggerRef}
                    type="button"
                    aria-expanded={megaOpen}
                    aria-haspopup="true"
                    onClick={() => setMegaOpen((v) => !v)}
                    onMouseEnter={() => setMegaOpen(true)}
                    className="flex min-h-11 items-center text-[11px] uppercase tracking-[0.18em] text-secondary-text transition-colors hover:text-foreground"
                  >
                    {item.label}
                  </button>
                </li>
              ) : (
                <li key={item.label}>
                  <Link
                    to={item.to}
                    onMouseEnter={() => setMegaOpen(false)}
                    activeProps={{ className: "text-foreground" }}
                    className="flex min-h-11 items-center text-[11px] uppercase tracking-[0.18em] text-secondary-text transition-colors hover:text-foreground"
                  >
                    {item.label}
                  </Link>
                </li>
              ),
            )}
          </ul>
        </nav>

        <div className="flex items-center gap-1">
          <button type="button" onClick={openSearch} aria-label="Search" className="grid size-11 place-items-center text-secondary-text hover:text-foreground">
            <Search className="size-5" />
          </button>
          <Link to="/account" aria-label="Account" className="hidden size-11 place-items-center text-secondary-text hover:text-foreground lg:grid">
            <User className="size-5" />
          </Link>
          <Link to="/wishlist" aria-label={`Wishlist, ${wishCount} items`} className="relative hidden size-11 place-items-center text-secondary-text hover:text-foreground lg:grid">
            <Heart className="size-5" />
            {wishCount ? <Badge>{wishCount}</Badge> : null}
          </Link>
          <button
            type="button"
            onClick={openCart}
            aria-label={`Bag, ${cartCount} items`}
            className="relative grid size-11 place-items-center text-secondary-text hover:text-foreground"
          >
            <ShoppingBag className="size-5" />
            {cartCount ? <Badge>{cartCount}</Badge> : null}
          </button>
        </div>
      </div>

      {megaOpen ? (
        <div
          className="hidden border-t border-border bg-deep lg:block"
          onKeyDown={(e) => {
            if (e.key === "Escape") {
              setMegaOpen(false);
              triggerRef.current?.focus();
            }
          }}
        >
          <div className="container-og grid grid-cols-6 gap-8 py-10">
            {CATEGORIES.map((cat) => (
              <div key={cat.slug}>
                <Link
                  to="/women/$categorySlug"
                  params={{ categorySlug: cat.slug }}
                  className="mb-4 block text-[11px] uppercase tracking-[0.18em] text-foreground hover:text-rose"
                >
                  {cat.name}
                </Link>
                <ul className="space-y-2">
                  {cat.children.map((child) => (
                    <li key={child.slug}>
                      <Link
                        to="/women/$categorySlug/$subcategorySlug"
                        params={{ categorySlug: cat.slug, subcategorySlug: child.slug }}
                        className="text-sm text-secondary-text hover:text-foreground"
                      >
                        {child.name}
                      </Link>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
            <div>
              <Eyebrow className="mb-4">Shop by Price</Eyebrow>
              <ul className="space-y-2">
                {SHOP_BY_PRICE.map((link) => (
                  <li key={link.to}>
                    <Link to={link.to} className="text-sm text-secondary-text hover:text-foreground">
                      {link.label}
                    </Link>
                  </li>
                ))}
                <li className="pt-2">
                  <Link to="/new-in" className="text-sm text-rose hover:text-rose-hover">
                    New In
                  </Link>
                </li>
              </ul>
            </div>
            <div>
              <Link to="/launchpad" className="block">
                <CategoryTilePlaceholder
                  slotId="nav.mega.editorial"
                  alt="Launchpad editorial tile"
                  label="MEGA MENU · LAUNCHPAD"
                  showMeta={false}
                />
                <p className="mt-3 text-sm text-foreground">Launchpad</p>
                <p className="text-xs text-muted-text">New labels, first runs.</p>
              </Link>
            </div>
          </div>
        </div>
      ) : null}
    </header>
  );
}

function Badge({ children }: { children: React.ReactNode }) {
  return (
    <span className="absolute right-1 top-1 grid min-w-4 place-items-center rounded-full bg-rose px-1 text-[10px] leading-4 text-white">
      {children}
    </span>
  );
}
