import { createFileRoute, Link } from "@tanstack/react-router";
import { allProducts } from "@/repositories/mock/catalog";
import { formatINR } from "@/lib/format";

export const Route = createFileRoute("/admin/catalog")({
  head: () => ({
    meta: [
      { title: "Admin catalog — OGURA" },
      { name: "description", content: "Mock catalogue table for the OGURA admin prototype." },
      { property: "og:title", content: "Admin catalog — OGURA" },
      { property: "og:description", content: "Mock catalogue table." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AdminCatalog,
});

function AdminCatalog() {
  const rows = allProducts.slice(0, 40);

  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[720px] text-left text-sm">
        <thead className="text-[11px] uppercase tracking-[0.16em] text-muted-text">
          <tr>
            <th className="border-b border-border pb-3">Style</th>
            <th className="border-b border-border pb-3">Designer</th>
            <th className="border-b border-border pb-3">Category</th>
            <th className="border-b border-border pb-3">Price</th>
            <th className="border-b border-border pb-3">Band</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((p) => (
            <tr key={p.id} className="border-b border-border">
              <td className="py-3 pr-4">
                <Link to="/product/$productSlug" params={{ productSlug: p.slug }} className="hover:text-rose">
                  {p.title}
                </Link>
              </td>
              <td className="py-3 pr-4 text-secondary-text">{p.brandName}</td>
              <td className="py-3 pr-4 text-secondary-text">
                {p.category} / {p.subcategory}
              </td>
              <td className="py-3 pr-4">{formatINR(p.price)}</td>
              <td className="py-3 text-secondary-text">{p.priceBand}</td>
            </tr>
          ))}
        </tbody>
      </table>
      <p className="mt-4 text-xs text-muted-text">Showing 40 of {allProducts.length} styles (prototype view).</p>
    </div>
  );
}
