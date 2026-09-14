import { createFileRoute, Link } from "@tanstack/react-router";
import { useOguraState } from "@/state/store";

export const Route = createFileRoute("/account/")({
  head: () => ({
    meta: [
      { title: "My account — OGURA" },
      { name: "description", content: "Your OGURA account overview: orders, wishlist and addresses." },
      { property: "og:title", content: "My account — OGURA" },
      { property: "og:description", content: "Your OGURA account overview." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AccountOverview,
});

function AccountOverview() {
  const profile = useOguraState((s) => s.profile);
  const orders = useOguraState((s) => s.orders);
  const wishlist = useOguraState((s) => s.wishlist);

  const cards = [
    { to: "/account/orders", label: "Orders", value: String(orders.length) },
    { to: "/account/wishlist", label: "Wishlist", value: String(wishlist.length) },
    { to: "/account/addresses", label: "Addresses", value: "Manage" },
    { to: "/account/profile", label: "Profile", value: profile.signedIn ? "Signed in" : "Guest" },
  ] as const;

  return (
    <div>
      <p className="text-sm text-secondary-text">
        {profile.signedIn ? `Welcome back, ${profile.name}.` : "You are browsing as a guest in this prototype."}
      </p>
      <div className="mt-6 grid gap-4 sm:grid-cols-2">
        {cards.map((card) => (
          <Link key={card.to} to={card.to} className="border border-border p-6 transition-colors hover:border-rose">
            <p className="text-[11px] uppercase tracking-[0.18em] text-muted-text">{card.label}</p>
            <p className="mt-2 font-display text-2xl">{card.value}</p>
          </Link>
        ))}
      </div>
    </div>
  );
}
