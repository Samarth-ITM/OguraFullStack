import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react";

interface UiContextValue {
  searchOpen: boolean;
  openSearch: () => void;
  closeSearch: () => void;
  cartOpen: boolean;
  openCart: () => void;
  closeCart: () => void;
  menuOpen: boolean;
  openMenu: () => void;
  closeMenu: () => void;
}

const UiContext = createContext<UiContextValue | null>(null);

export function UiProvider({ children }: { children: ReactNode }) {
  const [searchOpen, setSearchOpen] = useState(false);
  const [cartOpen, setCartOpen] = useState(false);
  const [menuOpen, setMenuOpen] = useState(false);

  const value = useMemo<UiContextValue>(
    () => ({
      searchOpen,
      openSearch: () => setSearchOpen(true),
      closeSearch: () => setSearchOpen(false),
      cartOpen,
      openCart: () => setCartOpen(true),
      closeCart: () => setCartOpen(false),
      menuOpen,
      openMenu: () => setMenuOpen(true),
      closeMenu: () => setMenuOpen(false),
    }),
    [searchOpen, cartOpen, menuOpen],
  );

  return <UiContext.Provider value={value}>{children}</UiContext.Provider>;
}

export function useUi(): UiContextValue {
  const ctx = useContext(UiContext);
  if (!ctx) throw new Error("useUi must be used inside UiProvider");
  return ctx;
}

export function useFocusTrap(active: boolean, onClose: () => void) {
  return useCallback(
    (node: HTMLElement | null) => {
      if (!node || !active) return;
      const selector =
        'a[href],button:not([disabled]),input,select,textarea,[tabindex]:not([tabindex="-1"])';
      const focusables = () => Array.from(node.querySelectorAll<HTMLElement>(selector));
      focusables()[0]?.focus();
      const handler = (e: KeyboardEvent) => {
        if (e.key === "Escape") {
          onClose();
          return;
        }
        if (e.key !== "Tab") return;
        const items = focusables();
        if (!items.length) return;
        const first = items[0];
        const last = items[items.length - 1];
        if (!first || !last) return;
        if (e.shiftKey && document.activeElement === first) {
          e.preventDefault();
          last.focus();
        } else if (!e.shiftKey && document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      };
      node.addEventListener("keydown", handler);
    },
    [active, onClose],
  );
}
