import { Logo } from "./Logo";

export function Nav() {
  return (
    <header className="px-5 pt-5">
      <div className="mx-auto max-w-md flex items-center justify-between">
        <Logo />
        <a
          href="#login"
          className="text-sm font-semibold text-foreground/80 hover:text-foreground transition"
        >
          Einloggen
        </a>
      </div>
    </header>
  );
}
