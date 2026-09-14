import { createFileRoute } from "@tanstack/react-router";
import { allProducts, allVariants } from "@/repositories/mock/catalog";
import { generatedBrands } from "@/data/generated/brands";

export const Route = createFileRoute("/admin/")({
  head: () => ({
    meta: [
      { title: "Admin overview — OGURA" },
      { name: "description", content: "Mock admin overview of the OGURA catalogue." },
      { property: "og:title", content: "Admin overview — OGURA" },
      { property: "og:description", content: "Mock admin catalogue metrics." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AdminOverview,
});

function AdminOverview() {
  const stats = [
    { label: "Product styles", value: String(allProducts.length) },
    { label: "Variants", value: String(allVariants.length) },
    { label: "Designers", value: String(generatedBrands.length) },
    { label: "Made to order", value: String(allProducts.filter((p) => p.madeToOrder).length) },
  ];

  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      {stats.map((s) => (
        <div key={s.label} className="border border-border p-5">
          <p className="text-[11px] uppercase tracking-[0.18em] text-muted-text">{s.label}</p>
          <p className="mt-2 font-display text-2xl">{s.value}</p>
        </div>
      ))}
    </div>
  );
}
