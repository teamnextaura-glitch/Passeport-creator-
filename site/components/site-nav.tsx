"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { Menu, X } from "lucide-react";

const LINKS = [
  ["#passeport", "Le Passeport"],
  ["#how", "Fonctionnement"],
  ["#createurs", "Créateurs"],
  ["#annonceurs", "Annonceurs"],
  ["#dao", "DAO"],
] as const;

/** Navigation fixe : ancres de la page d'accueil, menu repliable sous 768 px. */
export function SiteNav() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  return (
    <header className="fixed inset-x-0 top-0 z-50 border-b border-white/10 bg-bg/80 backdrop-blur">
      <a
        href="#contenu"
        className="sr-only focus:not-sr-only focus:absolute focus:left-4 focus:top-3 focus:rounded-pill focus:bg-primary focus:px-4 focus:py-2 focus:text-white"
      >
        Aller au contenu
      </a>
      <nav aria-label="Navigation principale" className="mx-auto flex h-16 max-w-7xl items-center justify-between gap-6 px-6">
        <Link href="/" className="font-display text-lg font-semibold tracking-wide text-text">
          PASSEPORT<span className="text-primary">·</span>CRÉATEUR
        </Link>

        <ul className="hidden items-center gap-6 text-sm text-muted md:flex">
          {LINKS.map(([href, label]) => (
            <li key={href}>
              <a href={href} className="hover:text-text">{label}</a>
            </li>
          ))}
        </ul>

        <div className="flex items-center gap-3">
          <Link
            href="/demo"
            className="hidden rounded-pill bg-primary px-5 py-2 text-sm font-medium text-white shadow-premium sm:inline-block"
          >
            Essayer la démo
          </Link>
          <button
            type="button"
            onClick={() => setOpen((v) => !v)}
            aria-expanded={open}
            aria-controls="menu-mobile"
            aria-label={open ? "Fermer le menu" : "Ouvrir le menu"}
            className="flex h-11 w-11 items-center justify-center rounded-pill border border-white/15 text-text md:hidden"
          >
            {open ? <X className="h-5 w-5" aria-hidden /> : <Menu className="h-5 w-5" aria-hidden />}
          </button>
        </div>
      </nav>

      {open && (
        <div id="menu-mobile" className="border-t border-white/10 bg-bg px-6 pb-6 md:hidden">
          <ul className="flex flex-col py-2 text-lg">
            {LINKS.map(([href, label]) => (
              <li key={href}>
                <a href={href} onClick={() => setOpen(false)} className="block py-3 text-muted hover:text-text">
                  {label}
                </a>
              </li>
            ))}
          </ul>
          <Link href="/demo" className="block rounded-pill bg-primary px-5 py-3 text-center font-medium text-white">
            Essayer la démo
          </Link>
        </div>
      )}
    </header>
  );
}
