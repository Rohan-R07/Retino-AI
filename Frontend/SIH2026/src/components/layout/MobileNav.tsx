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
  { path: "/screening/new", label: "New", icon: PlusCircle },
  { path: "/patients", label: "Screenings", icon: Users },
  { path: "/pending-reviews", label: "Reviews", icon: ClipboardCheck },
  { path: "/reports", label: "Reports", icon: FileText },
];

export function MobileNav() {
  const location = useLocation();

  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-50 bg-white border-t border-border lg:hidden"
      style={{ boxShadow: "0 -4px 16px rgba(14,157,191,0.1)" }}
      aria-label="Mobile navigation"
    >
      <ul className="flex items-center justify-around px-2 py-1">
        {navItems.map((item) => {
          const isActive =
            item.path === "/"
              ? location.pathname === "/"
              : location.pathname.startsWith(item.path);
          const Icon = item.icon;

          // Special style for "New" — pill FAB-style
          const isNew = item.path === "/screening/new";

          return (
            <li key={item.path}>
              <Link
                to={item.path}
                className={cn(
                  "flex flex-col items-center gap-1 px-3 py-2 text-xs font-medium transition-all",
                  isActive && !isNew ? "text-primary" : !isNew ? "text-muted-foreground" : ""
                )}
                aria-current={isActive ? "page" : undefined}
              >
                {isNew ? (
                  /* Floating action style for New Screening */
                  <div
                    className="-mt-5 flex h-12 w-12 items-center justify-center rounded-full text-white shadow-lg transition-transform hover:scale-105"
                    style={{ background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }}
                  >
                    <Icon className="h-5 w-5" />
                  </div>
                ) : (
                  <div
                    className={cn(
                      "flex h-8 w-8 items-center justify-center rounded-xl transition-all",
                      isActive ? "bg-primary-light" : ""
                    )}
                  >
                    <Icon
                      className="h-5 w-5"
                      style={{ color: isActive ? "#0E9DBF" : undefined }}
                    />
                  </div>
                )}
                <span
                  className={cn(isNew && "mt-1")}
                  style={{ color: isNew ? "#0E9DBF" : undefined }}
                >
                  {item.label}
                </span>
              </Link>
            </li>
          );
        })}
      </ul>
    </nav>
  );
}
