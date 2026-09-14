import { useEffect, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { toast } from "sonner";
import { signIn, signOut, useOguraState } from "@/state/store";
import { OgButton, OgInput } from "@/components/ui-og/primitives";

export const Route = createFileRoute("/account/profile")({
  head: () => ({
    meta: [
      { title: "Profile — OGURA" },
      { name: "description", content: "Your prototype profile details on OGURA." },
      { property: "og:title", content: "Profile — OGURA" },
      { property: "og:description", content: "Your prototype profile details." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ProfilePage,
});

function ProfilePage() {
  const profile = useOguraState((s) => s.profile);
  const [form, setForm] = useState({ name: profile.name, email: profile.email, phone: profile.phone });

  useEffect(() => {
    setForm({ name: profile.name, email: profile.email, phone: profile.phone });
  }, [profile.name, profile.email, profile.phone]);

  return (
    <div className="max-w-md space-y-5">
      <p className="text-sm text-secondary-text">
        This prototype stores your details only in this browser. There is no real account system.
      </p>
      <OgInput placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} />
      <OgInput placeholder="Email" type="email" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} />
      <OgInput placeholder="Phone" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} />
      <div className="flex flex-wrap gap-3">
        <OgButton
          onClick={() => {
            signIn({ ...form, signedIn: true });
            toast.success("Profile saved locally");
          }}
        >
          Save details
        </OgButton>
        {profile.signedIn ? (
          <OgButton
            variant="secondary"
            onClick={() => {
              signOut();
              setForm({ name: "", email: "", phone: "" });
              toast("Signed out of the prototype");
            }}
          >
            Sign out
          </OgButton>
        ) : null}
      </div>
    </div>
  );
}
