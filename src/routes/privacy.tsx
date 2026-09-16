import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/privacy")({
  head: () => ({
    meta: [
      { title: "Privacy policy — OGURA" },
      { name: "description", content: "Placeholder privacy text for a design prototype. No personal data is collected or transmitted." },
      { property: "og:title", content: "Privacy policy — OGURA" },
      { property: "og:description", content: "Placeholder privacy text for a design prototype. No personal data is collected or transmitted." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Data we store",
    "body": "Cart, wishlist and demo orders are kept in your browser's local storage only."
  },
  {
    "heading": "Analytics",
    "body": "No analytics or tracking scripts run in this prototype."
  },
  {
    "heading": "Third parties",
    "body": "No data is shared with any third party."
  },
  {
    "heading": "Clearing data",
    "body": "Clearing your browser storage removes everything this prototype has saved."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Legal"
      title="Privacy policy"
      intro="Placeholder privacy text for a design prototype. No personal data is collected or transmitted."
      sections={SECTIONS}
    />
  );
}
