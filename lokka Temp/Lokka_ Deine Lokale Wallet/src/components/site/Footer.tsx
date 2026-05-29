export function Footer() {
  return (
    <footer className="px-5 pt-4 pb-8">
      <div className="mx-auto max-w-md text-center">
        <p className="text-[11px] text-muted-foreground/70">
          © {new Date().getFullYear()} Lokka · Deine lokale Wallet
        </p>
      </div>
    </footer>
  );
}
