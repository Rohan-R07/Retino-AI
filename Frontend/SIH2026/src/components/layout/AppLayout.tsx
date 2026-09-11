import { Outlet } from "react-router-dom";
import { AppSidebar } from "./AppSidebar";
import { MobileNav } from "./MobileNav";
import { Header } from "./Header";

interface AppLayoutProps {
  title?: string;
  subtitle?: string;
}

/**
 * Main application shell with sidebar (desktop), header, and mobile bottom nav.
 */
export function AppLayout({ title, subtitle }: AppLayoutProps) {
  return (
    <div className="flex h-screen bg-background">
      {/* Desktop sidebar */}
      <AppSidebar />

      {/* Main content area */}
      <div className="flex flex-1 flex-col min-w-0">
        <Header title={title} subtitle={subtitle} />

        <main className="flex-1 overflow-y-auto pb-20 lg:pb-6">
          <Outlet />
        </main>
      </div>

      {/* Mobile bottom navigation */}
      <MobileNav />
    </div>
  );
}
