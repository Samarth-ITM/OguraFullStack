import { createFileRoute } from "@tanstack/react-router";
import { PlpEngine } from "@/components/plp/PlpEngine";

export const Route = createFileRoute("/launchpad")({
  head: () => ({
    meta: [
      { title: "Launchpad — new designers on OGURA" },
      { name: "description", content: "Emerging labels joining OGURA with small, considered first runs." },
      { property: "og:title", content: "Launchpad — new designers on OGURA" },
      { property: "og:description", content: "Discover emerging independent designers and their first collections." },
    ],
  }),
  component: Launchpad,
});

function Launchpad() {
  return (
    <PlpEngine
      title="Launchpad"
      description="First collections from emerging labels"
      crumbs={[{ label: "Home", to: "/" }, { label: "Launchpad" }]}
      baseQuery={{ launchpad: true }}
      templateKey="shop"
    />
  );
}
