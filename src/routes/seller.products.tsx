import { createFileRoute, Link } from "@tanstack/react-router";
import { allProducts, variantsByProduct } from "@/repositories/mock/catalog";
import { formatINR } from "@/lib/format";

export const Route = createFileRoute("/seller/products")({
  head: () => ({
    meta: [
      { title: "Seller products — OGURA" },
      { name: "description", content: "Mock product list for the OGURA seller prototype." },
      { property: "og:title", content: "Seller products — OGURA" },
      { property: "og:description", content: "Mock seller product inventory." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SellerProducts,
});

function SellerProducts() {
  const rows = allProducts.slice(0, 24);

  return (
    <div className="overflow-x-auto">
      <table className="w-full min-w-[640px] text-left text-sm">
        <thead className="text-[11px] uppercase tracking-[0.16em] text-muted-text">
          <tr>
            <th className="border-b border-border pb-3">Style</th>
            <th className="border-b border-border pb-3">Category</th>
            <th className="border-b border-border pb-3">Price</th>
            <th className="border-b border-border pb-3">Variants</th>
            <th className="border-b border-border pb-3">Status</th>
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
              <td className="py-3 pr-4 text-secondary-text">{p.subcategory}</td>
              <td className="py-3 pr-4">{formatINR(p.price)}</td>
              <td className="py-3 pr-4 text-secondary-text">{(variantsByProduct.get(p.id) ?? []).length}</td>
              <td className="py-3 text-secondary-text capitalize">{p.status}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
