import { BrowserRouter, Routes, Route } from "react-router-dom";
import { AppLayout } from "@/components/layout/AppLayout";
import { DashboardPage } from "@/pages/DashboardPage";
import { NewScreeningPage } from "@/pages/NewScreeningPage";
import { ScreeningDetailPage } from "@/pages/ScreeningDetailPage";
import { PatientsPage } from "@/pages/PatientsPage";
import { PendingReviewsPage } from "@/pages/PendingReviewsPage";
import { ReportsListPage } from "@/pages/ReportsListPage";
import { ReportPage } from "@/pages/ReportPage";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route
          element={
            <AppLayout
              title="Diabetic Retinopathy Screening"
              subtitle="Screening support for early detection and referral"
            />
          }
        >
          <Route path="/" element={<DashboardPage />} />
          <Route path="/screening/new" element={<NewScreeningPage />} />
          <Route path="/screening/:id" element={<ScreeningDetailPage />} />
          <Route path="/screening/:id/report" element={<ReportPage />} />
          <Route path="/patients" element={<PatientsPage />} />
          <Route path="/pending-reviews" element={<PendingReviewsPage />} />
          <Route path="/reports" element={<ReportsListPage />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
