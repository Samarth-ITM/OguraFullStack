import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/terms")({
  head: () => ({
    meta: [
      { title: "Terms of use — OGURA" },
      { name: "description", content: "Placeholder terms for a design prototype. Nothing here forms a binding agreement." },
      { property: "og:title", content: "Terms of use — OGURA" },
      { property: "og:description", content: "Placeholder terms for a design prototype. Nothing here forms a binding agreement." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Prototype status",
    "body": "This build demonstrates interface and merchandising only."
  },
  {
    "heading": "Pricing",
    "body": "All prices shown are illustrative."
  },
  {
    "heading": "Orders",
    "body": "No order placed here is fulfilled."
  },
  {
    "heading": "Content",
    "body": "Imagery is represented by placeholders throughout."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Legal"
      title="Terms of use"
      intro="Placeholder terms for a design prototype. Nothing here forms a binding agreement."
      sections={SECTIONS}
    />
  );
}
