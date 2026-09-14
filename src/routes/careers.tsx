import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/careers")({
  head: () => ({
    meta: [
      { title: "Work at OGURA — OGURA" },
      { name: "description", content: "We are a small team building a considered home for Indian design." },
      { property: "og:title", content: "Work at OGURA — OGURA" },
      { property: "og:description", content: "We are a small team building a considered home for Indian design." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Design",
    "body": "Product and brand designers who care about typography and restraint."
  },
  {
    "heading": "Engineering",
    "body": "Frontend engineers who enjoy performance and accessibility work."
  },
  {
    "heading": "Merchandising",
    "body": "Curators with a strong eye for emerging labels."
  },
  {
    "heading": "How to apply",
    "body": "Write to us through the contact page with a short note and your work."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Careers"
      title="Work at OGURA"
      intro="We are a small team building a considered home for Indian design."
      sections={SECTIONS}
    />
  );
}
