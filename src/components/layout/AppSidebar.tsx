import { Link, useLocation } from "react-router-dom";
import {
  LayoutDashboard,
  PlusCircle,
  Users,
  ClipboardCheck,
  FileText,
  Eye,
  Activity,
} from "lucide-react";
import { cn } from "@/lib/utils";

const navItems = [
  { path: "/", label: "Dashboard", icon: LayoutDashboard },
  { path: "/screening/new", label: "New Screening", icon: PlusCircle },
  { path: "/patients", label: "Screenings", icon: Users },
  { path: "/pending-reviews", label: "Pending Reviews", icon: ClipboardCheck },
  { path: "/reports", label: "Reports", icon: FileText },
];

interface AppSidebarProps {
  className?: string;
}

export function AppSidebar({ className }: AppSidebarProps) {
  const location = useLocation();

  return (
    <aside
      className={cn(
        "hidden lg:flex lg:flex-col lg:w-64 lg:bg-white lg:border-r lg:border-border",
        className
      )}
      style={{ boxShadow: "2px 0 12px rgba(14,157,191,0.06)" }}
    >
      {/* Brand */}
      <div className="flex items-center gap-3 px-5 py-5 border-b border-border">
        <div
          className="flex h-10 w-10 items-center justify-center rounded-xl text-white flex-shrink-0"
          style={{ background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }}
        >
          <Eye className="h-5 w-5" />
        </div>
        <div className="leading-tight">
          <p className="text-sm font-bold text-foreground">Retino-AI</p>
          <p className="text-xs" style={{ color: "#0E9DBF" }}>
            DR Screening System
          </p>
        </div>
      </div>

      {/* Online status chip */}
      <div className="mx-4 my-3 rounded-full px-3 py-1.5 flex items-center gap-2" style={{ background: "#E0F5FA" }}>
        <span className="relative flex h-2 w-2">
          <span className="animate-ping absolute inline-flex h-full w-full rounded-full opacity-75" style={{ backgroundColor: "#0E9DBF" }} />
          <span className="relative inline-flex h-2 w-2 rounded-full" style={{ backgroundColor: "#0E9DBF" }} />
        </span>
        <span className="text-xs font-medium" style={{ color: "#0A7A96" }}>
          System Online
        </span>
        <Activity className="h-3 w-3 ml-auto" style={{ color: "#0E9DBF" }} />
      </div>

      {/* Navigation */}
      <nav className="flex-1 px-3 py-2 overflow-y-auto" aria-label="Main navigation">
        <p className="px-3 pt-2 pb-1 text-xs font-semibold uppercase tracking-wider" style={{ color: "#5B7A8A" }}>
          Menu
        </p>
        <ul className="space-y-0.5">
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
                  className={cn(
                    "flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition-all duration-150",
                    isActive
                      ? "text-white shadow-sm"
                      : "text-muted-foreground hover:text-foreground"
                  )}
                  style={
                    isActive
                      ? { background: "linear-gradient(135deg, #0E9DBF 0%, #0A7A96 100%)" }
                      : undefined
                  }
                  onMouseEnter={(e) => {
                    if (!isActive) {
                      (e.currentTarget as HTMLAnchorElement).style.background = "#E0F5FA";
                      (e.currentTarget as HTMLAnchorElement).style.color = "#0A7A96";
                    }
                  }}
                  onMouseLeave={(e) => {
                    if (!isActive) {
                      (e.currentTarget as HTMLAnchorElement).style.background = "";
                      (e.currentTarget as HTMLAnchorElement).style.color = "";
                    }
                  }}
                  aria-current={isActive ? "page" : undefined}
                >
                  <div
                    className={cn(
                      "flex h-8 w-8 flex-shrink-0 items-center justify-center rounded-lg transition-all",
                      isActive ? "bg-white/20" : "bg-muted"
                    )}
                  >
                    <Icon className={cn("h-4 w-4", isActive ? "text-white" : "")} />
                  </div>
                  {item.label}
                </Link>
              </li>
            );
          })}
        </ul>
      </nav>

      {/* ECG decoration */}
      <div className="mx-4 ecg-line opacity-60" />

      {/* Footer */}
      <div className="px-5 py-4 border-t border-border">
        <div className="rounded-xl p-3 text-center" style={{ background: "linear-gradient(135deg, #E0F5FA 0%, #C8EDF6 100%)" }}>
          <p className="text-xs font-semibold" style={{ color: "#0A7A96" }}>
            Retino-AI v1.0.0
          </p>
          <p className="text-xs mt-0.5" style={{ color: "#5B7A8A" }}>
            SIH 2026 · AI Screening Tool
          </p>
        </div>
      </div>
    </aside>
  );
}
