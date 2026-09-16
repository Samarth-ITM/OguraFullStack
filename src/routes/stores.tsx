import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/stores")({
  head: () => ({
    meta: [
      { title: "Stores & studios — OGURA" },
      { name: "description", content: "OGURA is primarily online, with appointment-only studios in three cities." },
      { property: "og:title", content: "Stores & studios — OGURA" },
      { property: "og:description", content: "OGURA is primarily online, with appointment-only studios in three cities." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Mumbai",
    "body": "Kala Ghoda — styling appointments and made-to-order fittings."
  },
  {
    "heading": "New Delhi",
    "body": "Mehrauli — designer showcase studio."
  },
  {
    "heading": "Bengaluru",
    "body": "Indiranagar — pop-up calendar published each season."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Stores"
      title="Stores & studios"
      intro="OGURA is primarily online, with appointment-only studios in three cities."
      sections={SECTIONS}
    />
  );
}
