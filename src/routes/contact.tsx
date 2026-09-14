import { createFileRoute } from "@tanstack/react-router";
import { StaticPage } from "@/components/layout/StaticPage";

export const Route = createFileRoute("/contact")({
  head: () => ({
    meta: [
      { title: "Talk to us — OGURA" },
      { name: "description", content: "Our concierge team is available Monday to Saturday, 10am to 7pm IST." },
      { property: "og:title", content: "Talk to us — OGURA" },
      { property: "og:description", content: "Our concierge team is available Monday to Saturday, 10am to 7pm IST." },
    ],
  }),
  component: Page,
});

const SECTIONS = [
  {
    "heading": "Email",
    "body": "care@ogura.example — replies within one working day."
  },
  {
    "heading": "Phone",
    "body": "+91 00000 00000 — placeholder number for this prototype."
  },
  {
    "heading": "Studio",
    "body": "OGURA Studio, Mumbai. Visits by appointment only."
  }
];

function Page() {
  return (
    <StaticPage
      eyebrow="Contact"
      title="Talk to us"
      intro="Our concierge team is available Monday to Saturday, 10am to 7pm IST."
      sections={SECTIONS}
    />
  );
}
