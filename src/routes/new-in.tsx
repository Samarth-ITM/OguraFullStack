import { createFileRoute } from "@tanstack/react-router";
import { PlpEngine } from "@/components/plp/PlpEngine";

export const Route = createFileRoute("/new-in")({
  head: () => ({
    meta: [
      { title: "New In — OGURA" },
      { name: "description", content: "The newest arrivals from independent designers on OGURA." },
      { property: "og:title", content: "New In — OGURA" },
      { property: "og:description", content: "Newly added styles across clothing, ethnicwear, footwear and accessories." },
    ],
  }),
  component: NewIn,
});

function NewIn() {
  return (
    <PlpEngine
      title="New In"
      description="Most recently added styles"
      crumbs={[{ label: "Home", to: "/" }, { label: "New In" }]}
      baseQuery={{ newArrival: true, sort: "newest" }}
      templateKey="shop"
    />
  );
}
