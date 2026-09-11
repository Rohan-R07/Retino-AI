import { Eye, Menu, X, Bell, Search } from "lucide-react";
import { useState } from "react";
import { Link, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  PlusCircle,
  Users,
  ClipboardCheck,
  FileText,
} from "lucide-react";
import { cn } from "@/lib/utils";

const navItems = [
  { path: "/", label: "Dashboard", icon: LayoutDashboard },
  { path: "/screening/new", label: "New Screening", icon: PlusCircle },
  { path: "/patients", label: "Screenings", icon: Users },
  { path: "/pending-reviews", label: "Pending Reviews", icon: ClipboardCheck },
  { path: "/reports", label: "Reports", icon: FileText },
];

interface HeaderProps {
  title?: string;
  subtitle?: string;
}

export function Header({ title, subtitle }: HeaderProps) {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const location = useLocation();

  return (
    <header
      className="sticky top-0 z-40 bg-white border-b border-border"
      style={{ boxShadow: "0 2px 12px rgba(14,157,191,0.07)" }}
    >
      <div className="flex items-center justify-between px-4 py-3 sm:px-6">
        {/* Mobile: brand + hamburger */}
        <div className="flex items-center gap-3 lg:hidden">
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="flex h-9 w-9 items-center justify-center rounded-xl hover:bg-muted transition-colors"
            aria-label={mobileMenuOpen ? "Close menu" : "Open menu"}
          >
            {mobileMenuOpen ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
          </button>
          <div className="flex items-center gap-2">
            <div
              className="flex h-8 w-8 items-center justify-center rounded-lg text-white"
              style={{ background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }}
            >
              <Eye className="h-4 w-4" />
            </div>
            <span className="text-sm font-bold text-foreground">Retino-AI</span>
          </div>
        </div>

        {/* Desktop: page title */}
        <div className="hidden lg:flex lg:items-center lg:gap-3">
          {title && (
            <div>
              <h1 className="text-lg font-bold text-foreground">{title}</h1>
              {subtitle && (
                <p className="text-xs" style={{ color: "#5B7A8A" }}>
                  {subtitle}
                </p>
              )}
            </div>
          )}
        </div>

        {/* Right: search + notifications + avatar */}
        <div className="flex items-center gap-2">
          {/* Search pill */}
          <button
            className="hidden sm:flex items-center gap-2 rounded-full border border-border bg-muted px-3 py-2 text-sm text-muted-foreground hover:border-primary transition-colors"
            style={{ minWidth: 160 }}
          >
            <Search className="h-4 w-4 flex-shrink-0" />
            <span>Search...</span>
          </button>

          {/* Notification bell */}
          <button
            className="relative flex h-9 w-9 items-center justify-center rounded-xl border border-border bg-white hover:bg-muted transition-colors"
            aria-label="Notifications"
          >
            <Bell className="h-4 w-4 text-muted-foreground" />
            {/* Unread dot */}
            <span
              className="absolute top-1.5 right-1.5 h-2 w-2 rounded-full border-2 border-white"
              style={{ backgroundColor: "#0E9DBF" }}
            />
          </button>

          {/* Doctor avatar */}
          <div
            className="flex h-9 w-9 items-center justify-center rounded-xl text-white text-sm font-bold flex-shrink-0"
            style={{ background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }}
          >
            Dr
          </div>
        </div>
      </div>

      {/* Mobile slide-down menu */}
      {mobileMenuOpen && (
        <div className="border-t border-border bg-white px-4 py-3 lg:hidden">
          <nav aria-label="Mobile menu">
            <ul className="space-y-1">
              {navItems.map((item) => {
                const isActive =
                  item.path === "/"
                    ? location.pathname === "/"
                    : location.pathname.startsWith(item.path);
                const Icon = item.icon;

                return (
                  <li key={item.path}>
                    <Link
                      to={item.path}
                      onClick={() => setMobileMenuOpen(false)}
                      className={cn(
                        "flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-colors",
                        isActive
                          ? "text-white"
                          : "text-muted-foreground hover:bg-muted hover:text-foreground"
                      )}
                      style={
                        isActive
                          ? { background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }
                          : undefined
                      }
                    >
                      <Icon className="h-5 w-5 flex-shrink-0" />
                      {item.label}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </nav>
        </div>
      )}
    </header>
  );
}
