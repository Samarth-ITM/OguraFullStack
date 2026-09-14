import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { toast } from "sonner";
import type { Address } from "@/domain/commerce";
import { useOguraState } from "@/state/store";
import { EmptyState, OgButton, OgInput } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/account/addresses")({
  head: () => ({
    meta: [
      { title: "Saved addresses — OGURA" },
      { name: "description", content: "Manage the delivery addresses saved in this prototype." },
      { property: "og:title", content: "Saved addresses — OGURA" },
      { property: "og:description", content: "Manage saved delivery addresses." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AddressesPage,
});

const BLANK: Address = {
  fullName: "",
  phone: "",
  line1: "",
  line2: "",
  city: "",
  state: "",
  pincode: "",
};

function AddressesPage() {
  const draftAddress = useOguraState((s) => s.checkoutDraft?.address ?? null);
  const hasDraftAddress = Boolean(draftAddress?.fullName?.trim() && draftAddress?.line1?.trim());
  const list = hasDraftAddress && draftAddress ? [draftAddress] : [];

  const [form, setForm] = useState<Address>(BLANK);
  const [local, setLocal] = useState<Address[]>([]);
  const [error, setError] = useState("");

  const all = [...list, ...local];

  const add = () => {
    if (!form.fullName.trim() || !form.line1.trim() || !/^\d{6}$/.test(form.pincode)) {
      setError("Enter a name, street address and a valid 6-digit pincode.");
      return;
    }
    setError("");
    setLocal((l) => [...l, form]);
    setForm(BLANK);
    toast.success("Address added for this session");
  };

  return (
    <div className="space-y-10">
      {all.length === 0 ? (
        <EmptyState title="No addresses saved" body="Add one below to reuse it at checkout." />
      ) : (
        <ul className="grid gap-4 sm:grid-cols-2">
          {all.map((a, i) => (
            <li key={`${a.pincode}-${i}`} className="border border-border p-5 text-sm text-secondary-text">
              <p className="text-foreground">{a.fullName}</p>
              <p className="mt-2">
                {a.line1} {a.line2}
              </p>
              <p>
                {a.city}, {a.state} {a.pincode}
              </p>
            </li>
          ))}
        </ul>
      )}

      <div className="border border-border p-6">
        <h2 className="text-[11px] uppercase tracking-[0.18em]">Add an address</h2>
        <div className="mt-5 grid gap-4 sm:grid-cols-2">
          <OgInput placeholder="Full name" value={form.fullName} onChange={(e) => setForm({ ...form, fullName: e.target.value })} />
          <OgInput placeholder="Phone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
          <OgInput placeholder="Address line 1" value={form.line1} onChange={(e) => setForm({ ...form, line1: e.target.value })} />
          <OgInput placeholder="Address line 2" value={form.line2} onChange={(e) => setForm({ ...form, line2: e.target.value })} />
          <OgInput placeholder="City" value={form.city} onChange={(e) => setForm({ ...form, city: e.target.value })} />
          <OgInput placeholder="State" value={form.state} onChange={(e) => setForm({ ...form, state: e.target.value })} />
          <OgInput
            placeholder="Pincode"
            inputMode="numeric"
            value={form.pincode}
            onChange={(e) => setForm({ ...form, pincode: e.target.value.replace(/\D/g, "").slice(0, 6) })}
          />
        </div>
        {error ? (
          <p role="alert" className="mt-3 text-xs text-error">
            {error}
          </p>
        ) : null}
        <OgButton className="mt-5" onClick={add}>
          Save address
        </OgButton>
      </div>
    </div>
  );
}
