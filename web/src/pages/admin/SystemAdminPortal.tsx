import React, { useState, useEffect } from 'react';
import {
  LayoutDashboard,
  Building2,
  GraduationCap,
  Users,
  FileEdit,
  FileText,
  Flag,
  Coins,
  Megaphone,
  ScrollText,
  Settings,
  User,
} from 'lucide-react';
import { useNavigate, useLocation } from 'react-router-dom';
import LogoGoldSvg from '@/assets/logo/iskolarakologo-notext-gold.svg';
import { supabase } from '@/services/supabaseClient';
import { RejectRemarksModal } from './components/RejectRemarksModal';
import { AdminProgramDetailsModal } from './components/AdminProgramDetailsModal';
import { RejectScholarshipModal } from './components/RejectScholarshipModal';
import { AdminDashboardTab } from './components/AdminDashboardTab';
import { AdminProvidersTab } from './components/AdminProvidersTab';
import { AdminScholarshipsTab } from './components/AdminScholarshipsTab';
import { AdminStudentsTab } from './components/AdminStudentsTab';
import { AdminApplicationsTab } from './components/AdminApplicationsTab';
import { AdminDocumentsTab } from './components/AdminDocumentsTab';
import { AdminReportsTab } from './components/AdminReportsTab';
import { AdminFundsTab } from './components/AdminFundsTab';
import { AdminNotificationsTab } from './components/AdminNotificationsTab';
import type { AnnouncementTargetType } from './components/AdminNotificationsTab';
import { AdminLogsTab } from './components/AdminLogsTab';
import { AdminSettingsTab } from './components/AdminSettingsTab';
import { ProfileSettingsTab } from '@/components/common/ProfileSettingsTab';
import { sendAdminAnnouncement, fetchAdminBroadcasts, deleteNotification } from '@/services/notificationService';
import { fetchAuditLogs, createAuditLog } from '@/services/auditLogService';
import type {
  SystemAdminPortalProps,
  AdminTab,
  ProviderOrg,
  ProviderDocumentItem,
  ScholarshipAdminView,
  StudentAdminView,
  AdminReport,
  AuditLogEntry,
  RequirementItem,
} from './types';

export const SystemAdminPortal: React.FC<SystemAdminPortalProps> = ({ onLogout, showWelcome }) => {
  const navigate = useNavigate();
  const location = useLocation();

  const getTabFromPath = (): AdminTab => {
    const segment = location.pathname.replace(/^\/admin\/?/, '').split('/')[0];
    const validTabs: AdminTab[] = [
      'dashboard', 'providers', 'scholarships', 'students',
      'applications', 'documents', 'reports', 'funds',
      'notifications', 'logs', 'settings', 'profile'
    ];
    if (validTabs.includes(segment as AdminTab)) {
      return segment as AdminTab;
    }
    return 'dashboard';
  };

  const activeTab = getTabFromPath();
  const setActiveTab = (tab: AdminTab) => {
    navigate(`/admin/${tab}`);
  };


  const [currentAdminUserId, setCurrentAdminUserId] = useState<string | undefined>(undefined);
  const [adminBroadcasts, setAdminBroadcasts] = useState<any[]>([]);
  const [isSendingAnnouncement, setIsSendingAnnouncement] = useState(false);

  // Profile state loaded dynamically from Supabase
  const [profile, setProfile] = useState<{
    firstName: string;
    lastName: string;
    role: string;
  } | null>(null);

  const [toastMessage, setToastMessage] = useState<string | null>(null);

  // States for verification rejection modal
  const [isRejectModalOpen, setIsRejectModalOpen] = useState(false);
  const [rejectProviderId, setRejectProviderId] = useState<any>(null);
  const [rejectRemarks, setRejectRemarks] = useState('');

  // States for scholarship rejection modal
  const [isRejectScholarshipModalOpen, setIsRejectScholarshipModalOpen] = useState(false);
  const [rejectScholarshipId, setRejectScholarshipId] = useState<string | number | null>(null);
  const [rejectScholarshipRemarks, setRejectScholarshipRemarks] = useState('');

  useEffect(() => {
    const fetchProfile = async () => {
      try {
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) return;
        setCurrentAdminUserId(user.id);

        const { data: userData, error: userErr } = await supabase
          .from('users')
          .select('first_name, last_name, role')
          .eq('id', user.id)
          .single();

        if (userErr || !userData) return;

        setProfile({
          firstName: userData.first_name,
          lastName: userData.last_name,
          role: userData.role
        });

        // Show welcome toast dynamically only on successful login flow, not on page reload session restores
        if (showWelcome) {
          setToastMessage(`Welcome back, ${userData.first_name}!`);
          setTimeout(() => setToastMessage(null), 3000);
        }
      } catch (err) {
        console.error('Error fetching admin profile:', err);
      }
    };

    fetchProfile();
  }, [showWelcome]);

  const [isCollapsed, setIsCollapsed] = useState(false);
  const [collapsedGroups, setCollapsedGroups] = useState<Record<string, boolean>>({
    operations: false,
    oversight: false,
    control: false
  });

  const toggleGroup = (group: string) => {
    if (isCollapsed) return;
    setCollapsedGroups(prev => ({ ...prev, [group]: !prev[group] }));
  };

  // Search/Filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [providerFilter, setProviderFilter] = useState('All');

  // Modals / Details states
  const [selectedProvider, setSelectedProvider] = useState<ProviderOrg | null>(null);
  const [selectedStudent, setSelectedStudent] = useState<StudentAdminView | null>(null);
  const [providerPrograms, setProviderPrograms] = useState<any[]>([]);
  const [loadingPrograms, setLoadingPrograms] = useState(false);

  const [isChecklistCollapsed, setIsChecklistCollapsed] = useState(false);
  const [isOversightCollapsed, setIsOversightCollapsed] = useState(false);
  const [selectedScholarshipDetails, setSelectedScholarshipDetails] = useState<any | null>(null);
  const [loadingScholarships, setLoadingScholarships] = useState(false);

  useEffect(() => {
    if (!selectedProvider) {
      setProviderPrograms([]);
      return;
    }
    const fetchPrograms = async () => {
      setLoadingPrograms(true);
      try {
        const { data, error } = await supabase
          .from('scholarship_programs')
          .select('id, title, status, budget_total, total_slots, funding_frequency')
          .eq('provider_id', selectedProvider.id);
        if (!error && data) {
          setProviderPrograms(data);
        }
      } catch (err) {
        console.error('Error fetching provider programs:', err);
      } finally {
        setLoadingPrograms(false);
      }
    };
    fetchPrograms();
  }, [selectedProvider]);

  const renderSidebarBtn = (tab: AdminTab, label: string, icon: React.ReactNode) => {
    const isActive = activeTab === tab;
    return (
      <button
        onClick={() => setActiveTab(tab)}
        title={label}
        className={`w-full flex items-center rounded-xl text-xs font-semibold transition-all duration-200 cursor-pointer border-0 ${isCollapsed ? 'justify-center p-2.5' : 'gap-3 px-4 py-2.5'
          } ${isActive
            ? 'bg-[#2D5941] text-white shadow-md'
            : 'text-[#9BA89F] hover:bg-white/5 hover:text-white bg-transparent'
          }`}
      >
        <span className="shrink-0">{icon}</span>
        {!isCollapsed && <span>{label}</span>}
      </button>
    );
  };



  // Registered providers loaded from Supabase
  const [providers, setProviders] = useState<ProviderOrg[]>([]);
  const [providerRequirementsMap, setProviderRequirementsMap] = useState<Record<string, RequirementItem[]>>({});

  const [scholarships, setScholarships] = useState<ScholarshipAdminView[]>([]);

  const [students, setStudents] = useState<StudentAdminView[]>([]);
  const [loadingScholars, setLoadingScholars] = useState(false);

  const fetchStudentsAndScholars = async () => {
    setLoadingScholars(true);
    console.log('[Admin Scholar Management Debug]: Querying scholar & users tables from Supabase...');
    try {
      // 1. Query scholar table
      const { data: scholarRows, error: scholarErr } = await supabase
        .from('scholar')
        .select('*');

      if (scholarErr) {
        console.error('[Admin Scholar Fetch Error - scholar table]:', scholarErr);
        if (scholarErr.code === '42501' || scholarErr.message?.includes('permission') || scholarErr.message?.includes('policy')) {
          console.error('[Admin Scholar RLS Permission Warning]: RLS Policy blocking access to "scholar" table.');
        }
      }

      // 2. Query users table with role = 'scholar'
      const { data: userScholars, error: userErr } = await supabase
        .from('users')
        .select('*')
        .eq('role', 'scholar');

      if (userErr) {
        console.error('[Admin Scholar Fetch Error - users table]:', userErr);
        if (userErr.code === '42501' || userErr.message?.includes('permission') || userErr.message?.includes('policy')) {
          console.error('[Admin Users RLS Permission Warning]: RLS Policy blocking access to "users" table.');
        }
      }

      console.log(`[Admin Scholar Management Debug]: Found ${scholarRows?.length || 0} rows in scholar table, ${userScholars?.length || 0} in users table.`);

      if (scholarErr && userErr) {
        console.error('Error fetching scholars for system admin:', scholarErr || userErr);
        return;
      }

      let combinedMap: Map<string, StudentAdminView> = new Map();

      // Process scholar table records first
      if (scholarRows && scholarRows.length > 0) {
        const userIds = scholarRows.map((s: any) => s.user_id).filter(Boolean);
        let userEmailMap: Record<string, string> = {};

        if (userIds.length > 0) {
          try {
            const { data: userRows, error: uErr } = await supabase
              .from('users')
              .select('id, email, first_name, last_name')
              .in('id', userIds);

            if (uErr) {
              console.error('[Admin User Emails Error]:', uErr);
            } else if (userRows) {
              userRows.forEach((u: any) => {
                userEmailMap[u.id] = u.email;
              });
            }
          } catch (uErr) {
            console.warn('[Admin User Emails Exception]:', uErr);
          }
        }

        const formatYearLevel = (yl: any) => {
          if (yl === null || yl === undefined || yl === '') return '1st Year';
          const num = Number(yl);
          if (!isNaN(num)) {
            if (num === 1) return '1st Year';
            if (num === 2) return '2nd Year';
            if (num === 3) return '3rd Year';
            if (num === 4) return '4th Year';
            if (num === 5) return '5th Year';
            return `${num}th Year`;
          }
          return String(yl);
        };

        scholarRows.forEach((s: any) => {
          const fullName = [s.first_name, s.middle_name, s.last_name, s.suffix]
            .filter(Boolean)
            .join(' ')
            .trim() || 'Scholar Student';

          const email = userEmailMap[s.user_id] || s.email || 'scholar@iskolarako.app';
          const school = s.school || s.institution || 'Unspecified University';
          const course = s.course || 'Undergraduate Degree';
          const yearLevel = formatYearLevel(s.year_level);
          const gpa = s.gpa != null ? String(s.gpa) : (s.gwa != null ? String(s.gwa) : 'N/A');
          const citizenship = s.citizenship || 'Filipino';

          const rawVer = (s.verification_status || 'verified').toLowerCase();
          let verStatus: 'Verified' | 'Pending' | 'Flagged' = 'Verified';
          if (rawVer === 'pending' || rawVer === 'under_review') verStatus = 'Pending';
          else if (rawVer === 'flagged' || rawVer === 'rejected') verStatus = 'Flagged';

          const key = s.user_id || String(s.id);
          combinedMap.set(key, {
            id: s.id,
            name: fullName,
            email: email,
            school: school,
            course: course,
            yearLevel: yearLevel,
            gpa: gpa,
            citizenship: citizenship,
            verificationStatus: verStatus,
            accountStatus: 'Active',
          });
        });
      }

      // Merge registered users with role 'scholar' who might not have a full scholar record yet
      if (userScholars && userScholars.length > 0) {
        userScholars.forEach((u: any) => {
          if (!combinedMap.has(u.id)) {
            const fullName = `${u.first_name || ''} ${u.last_name || ''}`.trim() || u.email || 'Registered Scholar';
            combinedMap.set(u.id, {
              id: u.id,
              name: fullName,
              email: u.email || 'scholar@iskolarako.app',
              school: 'Unspecified University',
              course: 'Undergraduate Degree',
              yearLevel: '1st Year',
              gpa: '1.50',
              citizenship: 'Filipino',
              verificationStatus: 'Verified',
              accountStatus: 'Active',
            });
          }
        });
      }

      setStudents(Array.from(combinedMap.values()));
    } catch (err) {
      console.error('Error fetching scholars for admin:', err);
    } finally {
      setLoadingScholars(false);
    }
  };

  const handleStudentStatus = async (id: number | string, newStatus: 'Active' | 'Suspended') => {
    setStudents(prev =>
      prev.map(s => (s.id === id ? { ...s, accountStatus: newStatus } : s))
    );
    if (selectedStudent && selectedStudent.id === id) {
      setSelectedStudent(prev => prev ? { ...prev, accountStatus: newStatus } : null);
    }

    try {
      await supabase
        .from('scholar')
        .update({ verification_status: newStatus === 'Active' ? 'verified' : 'rejected' })
        .eq('id', id);
    } catch (err) {
      console.error('Error updating scholar status:', err);
    }

    setToastMessage(`Scholar account status set to ${newStatus}`);
    setTimeout(() => setToastMessage(null), 3000);
  };

  useEffect(() => {
    fetchStudentsAndScholars();
  }, [activeTab]);

  // Subscribe to realtime database updates for scholars and users
  useEffect(() => {
    const channel = supabase
      .channel('admin-students-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholar' },
        () => {
          fetchStudentsAndScholars();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'users' },
        () => {
          fetchStudentsAndScholars();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const [reports, setReports] = useState<AdminReport[]>([]);


  const [auditLogs, setAuditLogs] = useState<AuditLogEntry[]>([]);

  // Dashboard Metrics State
  const [dashboardMetrics, setDashboardMetrics] = useState<{
    totalStudents: number;
    totalProviders: number;
    verifiedProviders: number;
    pendingVerifications: number;
    activeScholarships: number;
    pendingApplications: number;
    approvedScholars: number;
    flaggedReports: number;
    totalReleased: number;
    pendingDisbursements: number;
  }>({
    totalStudents: 0,
    totalProviders: 0,
    verifiedProviders: 0,
    pendingVerifications: 0,
    activeScholarships: 0,
    pendingApplications: 0,
    approvedScholars: 0,
    flaggedReports: 0,
    totalReleased: 0,
    pendingDisbursements: 0,
  });
  const [_loadingDashboard, setLoadingDashboard] = useState(false);

  // System Config States
  const [categories, setCategories] = useState<{ id: string; name: string }[]>([]);
  const [maintenanceMode, setMaintenanceMode] = useState(false);
  const [announcementTarget, setAnnouncementTarget] = useState<AnnouncementTargetType>('Both');
  const [selectedTargetProviderId, setSelectedTargetProviderId] = useState<string>('');
  const [selectedTargetUserId, setSelectedTargetUserId] = useState<string>('');
  const [announcementTitle, setAnnouncementTitle] = useState('');
  const [announcementBody, setAnnouncementBody] = useState('');

  const fetchBroadcastsHistory = async () => {
    try {
      const data = await fetchAdminBroadcasts();
      setAdminBroadcasts(data);
    } catch (err) {
      console.error('Error fetching admin broadcasts:', err);
    }
  };

  useEffect(() => {
    if (activeTab === 'notifications') {
      fetchBroadcastsHistory();

      const channel = supabase
        .channel('admin-notifications-realtime')
        .on(
          'postgres_changes',
          { event: '*', schema: 'public', table: 'notifications' },
          () => {
            fetchBroadcastsHistory();
          }
        )
        .subscribe();

      return () => {
        supabase.removeChannel(channel);
      };
    }
  }, [activeTab]);

  // Fetch categories from the database on tab settings or mount
  const fetchCategories = async () => {
    try {
      const { data, error } = await supabase
        .from('scholarship_categories')
        .select('id, name')
        .order('name', { ascending: true });

      if (error) {
        console.error('Error fetching categories:', error);
        return;
      }
      setCategories(data || []);
    } catch (err) {
      console.error('Error in fetchCategories:', err);
    }
  };

  useEffect(() => {
    if (activeTab === 'settings') {
      fetchCategories();
    }
  }, [activeTab]);

  const fetchLogs = async () => {
    try {
      const logs = await fetchAuditLogs();
      setAuditLogs(logs);
    } catch (err) {
      console.error('Error fetching audit logs:', err);
    }
  };

  useEffect(() => {
    if (activeTab === 'logs' || activeTab === 'dashboard' || activeTab === 'reports') {
      fetchLogs();
    }
  }, [activeTab]);

  useEffect(() => {
    const channel = supabase
      .channel('audit-logs-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'audit_logs' },
        () => {
          fetchLogs();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const fetchRealProviders = async () => {
    try {
      // 1. Fetch requirements configs
      const { data: configData, error: configError } = await supabase
        .from('provider_requirements_config')
        .select('provider_type, required_fields');

      const reqsMap: Record<string, RequirementItem[]> = {};
      if (!configError && configData) {
        configData.forEach(c => {
          reqsMap[c.provider_type] = c.required_fields as RequirementItem[];
        });
      }
      // Populate defaults if missing
      const fallbackPublic = [
        { name: 'Government Charter or Mandate', description: 'Copy of the official establishing act/mandate', required: true },
        { name: 'Representative ID', description: 'Valid government ID of the focal person', required: true }
      ];
      const fallbackPrivate = [
        { name: 'SEC Registration Certificate', description: 'SEC Certificate of Registration', required: true },
        { name: 'BIR Form 2303', description: 'Certificate of Registration with BIR', required: true },
        { name: 'Business Permit', description: 'Current year Mayor\'s Business Permit', required: true }
      ];
      const fallbackNgo = [
        { name: 'SEC or DTI Registration Certificate', description: 'Official corporate registration copy', required: true },
        { name: 'BIR Certificate / Tax Exemption', description: 'Tax exemption certificate if applicable', required: false }
      ];

      if (!reqsMap.public) reqsMap.public = fallbackPublic;
      if (!reqsMap.private) reqsMap.private = fallbackPrivate;
      if (!reqsMap.ngo) reqsMap.ngo = fallbackNgo;

      setProviderRequirementsMap(reqsMap);

      // 2. Fetch providers
      const { data: providersData, error: providersError } = await supabase
        .from('provider')
        .select(`
          id,
          name,
          provider_type,
          verification_status,
          requirements_submitted,
          created_at
        `);

      if (providersError) throw providersError;
      if (!providersData) return;

      // 3. Fetch users for these providers (reverse lookup on users.provider_id)
      const providerIds = providersData.map(p => p.id);
      const usersByProviderId: Record<string, any> = {};

      if (providerIds.length > 0) {
        const { data: usersData } = await supabase
          .from('users')
          .select('id, first_name, last_name, email, provider_id')
          .in('provider_id', providerIds);

        usersData?.forEach(u => {
          if (u.provider_id) {
            usersByProviderId[u.provider_id] = u;
          }
        });
      }

      // Also query users with role = 'provider' or 'provider-member' as fallback
      const { data: providerRoleUsers } = await supabase
        .from('users')
        .select('id, first_name, last_name, email, provider_id')
        .in('role', ['provider', 'provider-member']);

      providerRoleUsers?.forEach(u => {
        if (u.provider_id && !usersByProviderId[u.provider_id]) {
          usersByProviderId[u.provider_id] = u;
        }
      });

      const formatted: ProviderOrg[] = providersData.map((p: any) => {
        const rep = usersByProviderId[p.id] || {};
        const repName = rep.first_name && rep.last_name ? `${rep.first_name} ${rep.last_name}` : 'No Representative';
        const repEmail = rep.email || 'N/A';
        const remarks = p.requirements_submitted?._remarks || '';
        // A provider's documents reflect on the admin side when submitted or when verified/under_review
        const isSubmittedToAdmin =
          p.verification_status !== 'pending' &&
          (p.requirements_submitted?._isSubmitted === true ||
            p.verification_status === 'verified' ||
            p.verification_status === 'under_review');
        const aiVerifications = p.requirements_submitted?._aiVerification || {};
        // Manual "Mark Verified"/"Flag" decisions made by an admin, keyed by document name.
        const docStatusOverrides: Record<string, { status?: ProviderDocumentItem['status']; remarks?: string }> =
          p.requirements_submitted?._docStatus || {};

        const docs: ProviderDocumentItem[] = isSubmittedToAdmin && p.requirements_submitted
          ? Object.entries(p.requirements_submitted)
            .filter(([name]) => !name.startsWith('_'))
            .map(([name, url]) => {
              const aiResult = aiVerifications[name];
              const override = docStatusOverrides[name];
              const isVerified = aiResult?.verificationStatus === 'verified' || p.verification_status === 'verified';
              const isFlagged = aiResult?.verificationStatus === 'flagged' || aiResult?.verificationStatus === 'rejected';
              // An admin's manual decision on a document always takes priority over the AI pre-scan verdict.
              const status = override?.status || (isVerified ? 'Verified' : isFlagged ? 'Flagged' : 'Pending');

              return {
                name,
                url: url as string,
                verified: status === 'Verified',
                status,
                remarks: override?.remarks ?? (aiResult?.flags?.[0] || ''),
                aiVerification: aiResult,
              };
            })
          : [];

        let uiStatus: ProviderOrg['status'] = 'Pending';
        if (p.verification_status === 'verified') uiStatus = 'Verified';
        else if (p.verification_status === 'under_review') uiStatus = 'Under Review';
        else if (p.verification_status === 'rejected') uiStatus = 'Suspended';

        return {
          id: p.id,
          name: p.name,
          representative: repName,
          email: repEmail,
          type: (p.provider_type === 'public' ? 'Government' : p.provider_type === 'private' ? 'Private' : 'NGO') as ProviderOrg['type'],
          status: uiStatus,
          documents: docs,
          dateRegistered: new Date(p.created_at).toLocaleDateString([], { month: 'short', day: '2-digit', year: 'numeric' }),
          remarks: remarks,
          isSubmitted: isSubmittedToAdmin
        };
      });

      setProviders(formatted);
    } catch (err) {
      console.error('Error fetching real providers:', err);
    }
  };

  useEffect(() => {
    if (activeTab === 'providers' || activeTab === 'dashboard' || activeTab === 'notifications') {
      fetchRealProviders();
    }
  }, [activeTab]);

  const fetchRealScholarships = async () => {
    setLoadingScholarships(true);
    try {
      const { data, error } = await supabase
        .from('scholarship_programs')
        .select(`
          id,
          title,
          budget_total,
          covers_tuition,
          covers_stipend,
          stipend_amount,
          covers_allowance,
          allowance_amount,
          status,
          created_at,
          category_id,
          scholarship_categories (
            name
          ),
          provider (
            name
          )
        `)
        .order('created_at', { ascending: false });

      if (error) throw error;
      if (data) {
        const formatted: ScholarshipAdminView[] = data.map((p: any) => {
          const realValue = p.budget_total || 0;
          return {
            id: p.id,
            title: p.title,
            providerName: p.provider?.name || 'Unknown Provider',
            category: p.scholarship_categories?.name || 'Uncategorized',
            amount: realValue,
            status: (p.status === 'active' || p.status === 'Active' || p.status === 'approved' || p.status === 'Approved' ? 'Approved' : p.status === 'closed' ? 'Suspended' : p.status === 'paused' ? 'Rejected' : 'Pending Review') as any,
            dateCreated: new Date(p.created_at).toLocaleDateString([], { month: 'short', day: '2-digit', year: 'numeric' })
          };
        });
        setScholarships(formatted);
      }
    } catch (err) {
      console.error('Error fetching real scholarships:', err);
    } finally {
      setLoadingScholarships(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'scholarships') {
      fetchRealScholarships();
    }
  }, [activeTab]);

  const fetchDashboardMetrics = async () => {
    setLoadingDashboard(true);
    try {
      // Fetch total students (from scholar table)
      const { count: studentCount } = await supabase
        .from('scholar')
        .select('*', { count: 'exact', head: true });

      // Fetch providers
      const { data: providersData } = await supabase
        .from('provider')
        .select('id, verification_status');

      const totalProviders = providersData?.length || 0;
      const verifiedProviders = providersData?.filter(p => p.verification_status === 'verified').length || 0;
      const pendingVerifications = providersData?.filter(p => p.verification_status === 'pending' || p.verification_status === 'under_review').length || 0;

      // Fetch active scholarships
      const { data: scholarshipsData } = await supabase
        .from('scholarship_programs')
        .select('id, status, budget_total')
        .eq('status', 'active');

      const activeScholarships = scholarshipsData?.length || 0;

      // Fetch pending applications
      const { count: pendingAppsCount } = await supabase
        .from('scholarship_applications')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending');

      // Fetch approved scholars (applications with approved status)
      const { count: approvedAppsCount } = await supabase
        .from('scholarship_applications')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'approved');

      const flaggedCount = 0;

      const totalReleased = scholarshipsData?.reduce((sum, p) => sum + (Number(p.budget_total) || 0), 0) || 0;
      const pendingDisbursements = 0;

      setDashboardMetrics({
        totalStudents: studentCount || 0,
        totalProviders,
        verifiedProviders,
        pendingVerifications,
        activeScholarships,
        pendingApplications: pendingAppsCount || 0,
        approvedScholars: approvedAppsCount || 0,
        flaggedReports: flaggedCount || 0,
        totalReleased,
        pendingDisbursements,
      });
    } catch (err) {
      console.error('Error fetching dashboard metrics:', err);
    } finally {
      setLoadingDashboard(false);
    }
  };

  useEffect(() => {
    if (activeTab === 'dashboard') {
      fetchDashboardMetrics();
    }
  }, [activeTab]);

  // Subscribe to realtime updates for dashboard metrics across relevant tables
  useEffect(() => {
    const channel = supabase
      .channel('admin-dashboard-metrics-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholar' },
        () => {
          fetchDashboardMetrics();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'provider' },
        () => {
          fetchDashboardMetrics();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholarship_programs' },
        () => {
          fetchDashboardMetrics();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholarship_applications' },
        () => {
          fetchDashboardMetrics();
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'fund_releases' },
        () => {
          fetchDashboardMetrics();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  // Subscribe to realtime database updates for real scholarships
  useEffect(() => {
    if (activeTab !== 'scholarships') return;

    const channel = supabase
      .channel('admin-scholarships-realtime')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'scholarship_programs' },
        () => {
          fetchRealScholarships();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [activeTab]);



  // Subscribe to realtime database updates for the provider and requirements config tables
  useEffect(() => {
    if (activeTab !== 'providers') return;

    const channel = supabase
      .channel('admin-providers-realtime')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'provider'
        },
        () => {
          fetchRealProviders();
        }
      )
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'provider_requirements_config'
        },
        () => {
          fetchRealProviders();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [activeTab]);

  // Subscribe to realtime database updates for scholarship categories in settings tab
  useEffect(() => {
    if (activeTab !== 'settings') return;

    const channel = supabase
      .channel('admin-categories-realtime')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'scholarship_categories'
        },
        () => {
          fetchCategories();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [activeTab]);

  // Keep selectedProvider synchronized whenever the providers list changes (e.g. a realtime update
  // from another admin session). Deliberately depends on `providers` only, NOT `selectedProvider` —
  // every admin action here (verify/flag a doc, approve, reactivate, etc.) already applies its own
  // optimistic update to `selectedProvider` before persisting. Re-running this on every
  // `selectedProvider` change would re-fire on that very optimistic update and immediately clobber it
  // with the still-stale `providers` snapshot from before the write finished — which is what made the
  // Verify/Flag buttons appear to do nothing.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    if (selectedProvider && providers.length > 0) {
      const updated = providers.find(p => p.id === selectedProvider.id);
      if (updated) {
        if (
          updated.status !== selectedProvider.status ||
          JSON.stringify(updated.documents) !== JSON.stringify(selectedProvider.documents) ||
          updated.remarks !== selectedProvider.remarks
        ) {
          setSelectedProvider(updated);
        }
      }
    }
  }, [providers]);

  // Category Multi-Add and Editing States
  const [showAddCategoryForm, setShowAddCategoryForm] = useState(false);
  const [categoryInputs, setCategoryInputs] = useState<string[]>(['']);
  const [editingCategoryId, setEditingCategoryId] = useState<string | null>(null);
  const [editingCategoryName, setEditingCategoryName] = useState<string>('');

  // Requirement Editing States
  const [editingReqIndex, setEditingReqIndex] = useState<number | null>(null);
  const [editReqName, setEditReqName] = useState<string>('');
  const [editReqDesc, setEditReqDesc] = useState<string>('');
  const [editReqRequired, setEditReqRequired] = useState<boolean>(true);

  // Provider Requirements Customization States
  const [selectedProviderType, setSelectedProviderType] = useState<string>('public');
  const [reqItems, setReqItems] = useState<RequirementItem[]>([]);
  const [newReqName, setNewReqName] = useState('');
  const [newReqDesc, setNewReqDesc] = useState('');
  const [newReqRequired, setNewReqRequired] = useState(true);
  const [newReqProviderTypes, setNewReqProviderTypes] = useState<string[]>(['public']);
  const [isSavingReq, setIsSavingReq] = useState(false);


  // Load requirements configurations from Supabase or use defaults
  const fetchRequirementsConfig = async (type: string) => {
    try {
      const { data, error } = await supabase
        .from('provider_requirements_config')
        .select('required_fields')
        .eq('provider_type', type)
        .maybeSingle();

      if (error) {
        console.error('Error fetching requirements config:', error);
        return;
      }

      if (data && data.required_fields && Array.isArray(data.required_fields)) {
        setReqItems(data.required_fields as RequirementItem[]);
      } else {
        // Fallback default templates
        if (type === 'public') {
          setReqItems([
            { name: 'Government Charter or Mandate', description: 'Copy of the official establishing act/mandate', required: true },
            { name: 'Representative ID', description: 'Valid government ID of the focal person', required: true }
          ]);
        } else if (type === 'private') {
          setReqItems([
            { name: 'SEC Registration Certificate', description: 'SEC Certificate of Registration', required: true },
            { name: 'BIR Form 2303', description: 'Certificate of Registration with BIR', required: true },
            { name: 'Business Permit', description: 'Current year Mayor\'s Business Permit', required: true }
          ]);
        } else {
          setReqItems([
            { name: 'SEC or DTI Registration Certificate', description: 'Official corporate registration copy', required: true },
            { name: 'BIR Certificate / Tax Exemption', description: 'Tax exemption certificate if applicable', required: false }
          ]);
        }
      }
    } catch (err) {
      console.error('Error in fetchRequirementsConfig:', err);
    }
  };

  useEffect(() => {
    if (activeTab === 'settings') {
      fetchRequirementsConfig(selectedProviderType);
    }
  }, [activeTab, selectedProviderType]);

  const handleSaveRequirements = async () => {
    setIsSavingReq(true);
    try {
      const { error } = await supabase
        .from('provider_requirements_config')
        .upsert({
          provider_type: selectedProviderType,
          required_fields: reqItems,
          updated_at: new Date().toISOString()
        }, {
          onConflict: 'provider_type'
        });

      if (error) throw error;
      showToast('Requirements configuration saved successfully!');
      addAuditLog('UPDATED REQUIREMENTS CONFIG', `Provider Type: ${selectedProviderType}`);
    } catch (err: any) {
      console.error('Error saving requirements:', err);
      showToast(`Error: ${err.message || 'Failed to save configuration.'}`);
    } finally {
      setIsSavingReq(false);
    }
  };

  const handleAddRequirement = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newReqName.trim()) return;
    if (newReqProviderTypes.length === 0) {
      showToast('Please select at least one provider type.');
      return;
    }

    const item: RequirementItem = {
      name: newReqName.trim(),
      description: newReqDesc.trim(),
      required: newReqRequired
    };

    // Save to each selected provider type
    let lastSuccessType = '';
    for (const pType of newReqProviderTypes) {
      let targetItems: RequirementItem[] = [];
      try {
        const { data } = await supabase
          .from('provider_requirements_config')
          .select('required_fields')
          .eq('provider_type', pType)
          .maybeSingle();

        if (data?.required_fields && Array.isArray(data.required_fields)) {
          targetItems = data.required_fields as RequirementItem[];
        }
      } catch (err) {
        console.warn(`Could not fetch existing requirements for ${pType}, starting fresh.`);
      }

      const updated = [...targetItems, item];

      try {
        const { error } = await supabase
          .from('provider_requirements_config')
          .upsert({
            provider_type: pType,
            required_fields: updated,
            updated_at: new Date().toISOString()
          }, {
            onConflict: 'provider_type'
          });

        if (error) throw error;

        lastSuccessType = pType;
        addAuditLog('ADDED REQUIREMENT', `${item.name} → ${pType}`);
        // If this type is currently viewed, update the list
        if (pType === selectedProviderType) {
          setReqItems(updated);
        }
      } catch (err: any) {
        console.error(`Error saving requirement to ${pType}:`, err);
        showToast(`Failed to save to ${pType}: ${err.message || 'database error'}`);
      }
    }

    if (lastSuccessType) {
      const typeLabels = newReqProviderTypes.map(t =>
        t === 'public' ? 'Government' : t === 'private' ? 'Private Partner' : 'NGO'
      ).join(', ');
      showToast(`"${item.name}" added to: ${typeLabels}.`);
      // Switch filter to last saved type so user can see it
      setSelectedProviderType(lastSuccessType);
      await fetchRequirementsConfig(lastSuccessType);
    }

    setNewReqName('');
    setNewReqDesc('');
    setNewReqRequired(true);
  };

  const handleRemoveRequirement = async (index: number) => {
    const deletedItemName = reqItems[index]?.name;
    const updated = reqItems.filter((_, idx) => idx !== index);
    setReqItems(updated);
    if (editingReqIndex === index) {
      setEditingReqIndex(null);
    }

    // Persist deletion to database immediately
    try {
      const { error } = await supabase
        .from('provider_requirements_config')
        .upsert({
          provider_type: selectedProviderType,
          required_fields: updated,
          updated_at: new Date().toISOString()
        }, {
          onConflict: 'provider_type'
        });

      if (error) throw error;

      // Clean up uploaded documents for affected providers
      if (deletedItemName) {
        const { data: affectedProviders } = await supabase
          .from('provider')
          .select('id, requirements_submitted')
          .eq('provider_type', selectedProviderType);

        if (affectedProviders) {
          for (const prov of affectedProviders) {
            if (prov.requirements_submitted && prov.requirements_submitted[deletedItemName]) {
              const newReqs = { ...prov.requirements_submitted };
              delete newReqs[deletedItemName];

              await supabase
                .from('provider')
                .update({
                  requirements_submitted: newReqs,
                  updated_at: new Date().toISOString()
                })
                .eq('id', prov.id);
            }
          }
        }
      }

      showToast('Requirement removed and database cleaned up.');
      addAuditLog('REMOVED REQUIREMENT & CLEANED UP SUBMISSIONS', `Provider Type: ${selectedProviderType}, Requirement: ${deletedItemName}`);
    } catch (err: any) {
      console.error('Error saving after removal:', err);
      showToast(`Failed to save: ${err.message || 'database error'}`);
    }
  };

  const handleSaveMultipleCategories = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    const allNames: string[] = [];
    categoryInputs.forEach(input => {
      input.split(',').forEach(part => {
        const trimmed = part.trim();
        if (trimmed && !allNames.includes(trimmed) && !categories.some(c => c.name.toLowerCase() === trimmed.toLowerCase())) {
          allNames.push(trimmed);
        }
      });
    });

    if (allNames.length === 0) {
      showToast('Please enter at least one new category name.');
      return;
    }

    try {
      const recordsToInsert = allNames.map(name => ({ name }));
      const { data, error } = await supabase
        .from('scholarship_categories')
        .insert(recordsToInsert)
        .select();

      if (error) throw error;

      if (data) {
        setCategories(prev => [...prev, ...data]);
        addAuditLog('ADDED SCHOLARSHIP CATEGORIES', allNames.join(', '));
        showToast(`Added ${data.length} new category(ies).`);
      }
      setCategoryInputs(['']);
      setShowAddCategoryForm(false);
    } catch (err: any) {
      console.error('Error saving categories:', err);
      showToast(`Failed to save categories: ${err.message || 'database error'}`);
    }
  };

  const handleStartEditCategory = (cat: { id: string; name: string }) => {
    setEditingCategoryId(cat.id);
    setEditingCategoryName(cat.name);
  };

  const handleSaveEditCategory = async (id: string) => {
    const trimmed = editingCategoryName.trim();
    if (!trimmed) {
      showToast('Category name cannot be empty.');
      return;
    }

    try {
      const { error } = await supabase
        .from('scholarship_categories')
        .update({ name: trimmed })
        .eq('id', id);

      if (error) throw error;

      setCategories(prev => prev.map(c => c.id === id ? { ...c, name: trimmed } : c));
      addAuditLog('UPDATED SCHOLARSHIP CATEGORY', trimmed);
      showToast(`Category updated to "${trimmed}".`);
      setEditingCategoryId(null);
    } catch (err: any) {
      console.error('Error updating category:', err);
      showToast(`Failed to update category: ${err.message || 'database error'}`);
    }
  };

  // Requirement Edit Handlers
  const handleStartEditRequirement = (idx: number, item: RequirementItem) => {
    setEditingReqIndex(idx);
    setEditReqName(item.name);
    setEditReqDesc(item.description || '');
    setEditReqRequired(item.required);
  };

  const handleSaveEditRequirement = async (idx: number) => {
    if (!editReqName.trim()) {
      showToast('Requirement title cannot be empty.');
      return;
    }
    const updated = [...reqItems];
    updated[idx] = {
      name: editReqName.trim(),
      description: editReqDesc.trim(),
      required: editReqRequired
    };
    setReqItems(updated);
    setEditingReqIndex(null);

    // Persist to database immediately
    try {
      const { error } = await supabase
        .from('provider_requirements_config')
        .upsert({
          provider_type: selectedProviderType,
          required_fields: updated,
          updated_at: new Date().toISOString()
        }, {
          onConflict: 'provider_type'
        });

      if (error) throw error;
      showToast('Requirement saved successfully!');
      addAuditLog('UPDATED REQUIREMENTS CONFIG', `Provider Type: ${selectedProviderType}`);
    } catch (err: any) {
      console.error('Error saving requirement edit:', err);
      showToast(`Failed to save: ${err.message || 'database error'}`);
    }
  };



  const showToast = (message: string) => {
    setToastMessage(message);
    setTimeout(() => setToastMessage(null), 3000);
  };

  const addAuditLog = async (action: string, target: string) => {
    try {
      const adminUser = profile ? `${profile.firstName} ${profile.lastName}`.trim() : 'admin01';
      const newLog = await createAuditLog(action, target, adminUser || 'admin01');
      setAuditLogs(prev => [newLog, ...prev]);
    } catch (err) {
      console.error('Error adding audit log:', err);
    }
  };

  // HANDLERS
  const handleVerifyProvider = async (id: any, nextStatus: ProviderOrg['status'], customRemarks?: string) => {
    let remarks = '';
    if (nextStatus === 'Suspended') {
      if (customRemarks === undefined) {
        setRejectProviderId(id);
        setRejectRemarks('');
        setIsRejectModalOpen(true);
        return;
      }
      remarks = customRemarks;
    }

    // If approving a suspended provider, invoke handleReactivateProvider to lift suspension and clear remarks
    const currentStatus = providers.find(p => p.id === id)?.status;
    if (nextStatus === 'Verified' && currentStatus === 'Suspended') {
      await handleReactivateProvider(id);
      return;
    }

    // Determine DB status
    let dbStatus = 'pending';
    if (nextStatus === 'Verified') dbStatus = 'verified';
    else if (nextStatus === 'Under Review') dbStatus = 'under_review';
    else if (nextStatus === 'Suspended') dbStatus = 'rejected';

    const isUuid = typeof id === 'string';

    if (isUuid) {
      try {
        const { data: currentProv } = await supabase
          .from('provider')
          .select('requirements_submitted')
          .eq('id', id)
          .single();

        const updatedReqs = {
          ...(currentProv?.requirements_submitted || {}),
          _remarks: remarks || undefined,
          _isSubmitted: nextStatus === 'Verified' ? true : nextStatus === 'Suspended' ? false : currentProv?.requirements_submitted?._isSubmitted
        };

        const { error } = await supabase
          .from('provider')
          .update({
            verification_status: dbStatus,
            requirements_submitted: updatedReqs,
            updated_at: new Date().toISOString()
          })
          .eq('id', id);

        if (error) throw error;
        showToast(`Successfully updated provider in database!`);
      } catch (err: any) {
        console.error('Error updating provider verification status:', err);
        showToast(`Database Error: ${err.message}`);
        return;
      }
    }

    setProviders(prev =>
      prev.map(p => {
        if (p.id === id) {
          const updated = {
            ...p,
            status: nextStatus,
            documents: p.documents.map(d => ({ ...d, verified: nextStatus === 'Verified' }))
          };
          if (selectedProvider && selectedProvider.id === id) {
            setSelectedProvider(updated);
          }
          return updated;
        }
        return p;
      })
    );
    const providerName = providers.find(p => p.id === id)?.name || 'Unknown';
    addAuditLog(`UPDATED PROVIDER STATUS: ${nextStatus}`, providerName);
    showToast(`Provider "${providerName}" status updated to ${nextStatus}.`);

    if (nextStatus === 'Suspended') {
      setIsRejectModalOpen(false);
    }
  };

  // Lets an admin lift a suspension directly and restore the provider to Verified, bypassing the
  // normal "must re-upload and re-submit documents" gate in handleVerifyProvider — used when the
  // admin has already resolved the issue that led to suspension.
  const handleReactivateProvider = async (id: any) => {
    const isUuid = typeof id === 'string';
    let fetchedReqs: Record<string, any> | null = null;

    if (isUuid) {
      try {
        const { data: currentProv } = await supabase
          .from('provider')
          .select('requirements_submitted')
          .eq('id', id)
          .single();

        fetchedReqs = {
          ...(currentProv?.requirements_submitted || {}),
          _isSubmitted: true,
        };
        delete (fetchedReqs as any)._remarks;

        const { error } = await supabase
          .from('provider')
          .update({
            verification_status: 'verified',
            requirements_submitted: fetchedReqs,
            updated_at: new Date().toISOString(),
          })
          .eq('id', id);

        if (error) throw error;
      } catch (err: any) {
        console.error('Error reactivating provider:', err);
        showToast(`Database Error: ${err.message}`);
        return;
      }
    }

    setProviders(prev =>
      prev.map(p => {
        if (p.id === id) {
          let updatedDocs = p.documents.map(d => ({ ...d, verified: true, status: 'Verified' as const }));

          if (updatedDocs.length === 0 && fetchedReqs) {
            const aiVerifs = fetchedReqs._aiVerification || {};
            const docStatusOverrides = fetchedReqs._docStatus || {};
            updatedDocs = Object.entries(fetchedReqs)
              .filter(([name]) => !name.startsWith('_'))
              .map(([name, url]) => ({
                name,
                url: String(url),
                verified: true,
                status: docStatusOverrides[name]?.status || 'Verified',
                remarks: docStatusOverrides[name]?.remarks || undefined,
                aiVerification: aiVerifs[name] || undefined,
              }));
          }

          const updated: ProviderOrg = {
            ...p,
            status: 'Verified',
            remarks: '',
            documents: updatedDocs,
          };
          if (selectedProvider && selectedProvider.id === id) {
            setSelectedProvider(updated);
          }
          return updated;
        }
        return p;
      })
    );

    const providerName = providers.find(p => p.id === id)?.name || 'Unknown';
    addAuditLog('RE-ACTIVATED SUSPENDED PROVIDER', providerName);
    showToast(`Provider "${providerName}" has been re-activated and verified.`);
  };

  const handleUpdateProviderDocs = async (
    providerId: any,
    updatedDocs: ProviderDocumentItem[],
    newStatus?: ProviderOrg['status'],
    newRemarks?: string
  ) => {
    try {
      const { data: currentProv } = await supabase
        .from('provider')
        .select('requirements_submitted')
        .eq('id', providerId)
        .single();

      const aiVerifMap: Record<string, any> = {
        ...(currentProv?.requirements_submitted?._aiVerification || {}),
      };
      // Persist each document's manual "Mark Verified"/"Flag" decision so it survives a re-fetch
      // (e.g. navigating to another tab and back) instead of reverting to the AI pre-scan verdict.
      const docStatusMap: Record<string, { status?: string; remarks?: string }> = {
        ...(currentProv?.requirements_submitted?._docStatus || {}),
      };

      updatedDocs.forEach(d => {
        if (d.aiVerification) {
          aiVerifMap[d.name] = d.aiVerification;
        }
        if (d.status) {
          docStatusMap[d.name] = { status: d.status, remarks: d.remarks || '' };
        }
      });

      const updatedReqs = {
        ...(currentProv?.requirements_submitted || {}),
        _aiVerification: aiVerifMap,
        _docStatus: docStatusMap,
      };

      if (newRemarks !== undefined) {
        updatedReqs._remarks = newRemarks;
      }

      let dbStatus: string | undefined = undefined;
      if (newStatus === 'Verified') dbStatus = 'verified';
      else if (newStatus === 'Under Review') dbStatus = 'under_review';
      else if (newStatus === 'Suspended') dbStatus = 'rejected';

      const updatePayload: any = {
        requirements_submitted: updatedReqs,
        updated_at: new Date().toISOString(),
      };
      if (dbStatus) {
        updatePayload.verification_status = dbStatus;
      }

      await supabase
        .from('provider')
        .update(updatePayload)
        .eq('id', providerId);

      setProviders(prev =>
        prev.map(p => {
          if (p.id === providerId) {
            const updated: ProviderOrg = {
              ...p,
              status: newStatus || p.status,
              documents: updatedDocs,
              remarks: newRemarks !== undefined ? newRemarks : p.remarks,
            };
            if (selectedProvider && selectedProvider.id === providerId) {
              setSelectedProvider(updated);
            }
            return updated;
          }
          return p;
        })
      );
    } catch (err) {
      console.error('Error persisting provider docs:', err);
    }
  };

  const handleScholarshipAction = async (id: number | string, action: 'Approved' | 'Rejected' | 'Suspended') => {
    // For Rejected, open the remarks modal instead of acting immediately
    if (action === 'Rejected') {
      setRejectScholarshipId(id);
      setRejectScholarshipRemarks('');
      setIsRejectScholarshipModalOpen(true);
      return;
    }

    // Map action to DB status value
    let dbStatus = 'active';
    if (action === 'Approved') dbStatus = 'active';
    else if (action === 'Suspended') dbStatus = 'closed';

    console.log(`[Admin] Updating scholarship ${id} → status: "${dbStatus}"`);

    const { error } = await supabase
      .from('scholarship_programs')
      .update({ status: dbStatus })
      .eq('id', id);

    if (error) {
      console.error('[Admin] DB update error:', error.code, error.message, error.details, error.hint);
      showToast(`DB Error (${error.code}): ${error.message}`);
      return;
    }

    console.log(`[Admin] Scholarship ${id} updated to "${dbStatus}" successfully`);
    fetchRealScholarships();
    const title = scholarships.find(s => s.id === id)?.title || 'Scholarship';
    addAuditLog(`${action.toUpperCase()} SCHOLARSHIP`, title);
    showToast(`Scholarship "${title}" is now ${action}.`);
  };

  const handleConfirmRejectScholarship = async () => {
    if (!rejectScholarshipId) return;
    const remarks = rejectScholarshipRemarks.trim();
    if (!remarks) {
      showToast('Please enter rejection remarks.');
      return;
    }

    const { error } = await supabase
      .from('scholarship_programs')
      .update({ status: 'paused', rejection_remarks: remarks })
      .eq('id', rejectScholarshipId);

    if (error) {
      console.error('[Admin] Reject error:', error.code, error.message);
      showToast(`DB Error: ${error.message}`);
      return;
    }

    const title = scholarships.find(s => s.id === rejectScholarshipId)?.title || 'Scholarship';
    addAuditLog('REJECTED SCHOLARSHIP', title);
    showToast(`Scholarship "${title}" has been rejected.`);
    setIsRejectScholarshipModalOpen(false);
    setRejectScholarshipId(null);
    setRejectScholarshipRemarks('');
    fetchRealScholarships();
  };

  const handleReportAction = (id: number, action: 'Resolved' | 'Dismissed') => {
    setReports(prev => prev.map(r => (r.id === id ? { ...r, status: action } : r)));
    const report = reports.find(r => r.id === id);
    addAuditLog(`RESOLVED REPORT #${id}`, `${action} - ${report?.reportedEntity}`);
    showToast(`Report #${id} has been ${action}.`);
  };

  const handleSendAnnouncement = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!announcementTitle.trim() || !announcementBody.trim()) return;

    let targetName = '';
    if (announcementTarget === 'Specific Provider' && selectedTargetProviderId) {
      const p = providers.find(item => String(item.id) === String(selectedTargetProviderId));
      targetName = p ? p.name : '';
    } else if (announcementTarget === 'Specific Scholar' && selectedTargetUserId) {
      const s = students.find(item => String(item.id) === String(selectedTargetUserId));
      targetName = s ? s.name : '';
    }

    setIsSendingAnnouncement(true);
    try {
      const res = await sendAdminAnnouncement({
        title: announcementTitle.trim(),
        message: announcementBody.trim(),
        target: announcementTarget,
        targetProviderId: announcementTarget === 'Specific Provider' ? selectedTargetProviderId : undefined,
        targetUserId: announcementTarget === 'Specific Scholar' ? selectedTargetUserId : undefined,
        targetName: targetName || undefined,
        adminId: currentAdminUserId,
        adminName: profile ? `${profile.firstName} ${profile.lastName}` : 'System Admin'
      });

      if (res.success) {
        addAuditLog(`BROADCAST ANNOUNCEMENT`, `Target: ${announcementTarget}${targetName ? ` (${targetName})` : ''} - Title: ${announcementTitle} (${res.count} users)`);
        showToast(`Announcement successfully sent to ${targetName || announcementTarget} (${res.count} user${res.count === 1 ? '' : 's'})!`);
        setAnnouncementTitle('');
        setAnnouncementBody('');
        setSelectedTargetProviderId('');
        setSelectedTargetUserId('');
        await fetchBroadcastsHistory();
      } else {
        showToast(`Failed to send broadcast: ${res.error || 'Unknown error'}`);
      }
    } catch (err: any) {
      console.error('Error broadcasting admin announcement:', err);
      showToast(`Broadcast failed: ${err.message || 'Error occurred'}`);
    } finally {
      setIsSendingAnnouncement(false);
    }
  };

  const handleDeleteAdminBroadcast = async (id: string | number) => {
    try {
      await deleteNotification(String(id));
      showToast('Broadcast deleted from log.');
      await fetchBroadcastsHistory();
    } catch (err) {
      console.error('Error deleting broadcast:', err);
    }
  };

  const handleDeleteCategory = async (id: string, name: string) => {
    try {
      const { error } = await supabase
        .from('scholarship_categories')
        .delete()
        .eq('id', id);

      if (error) throw error;

      setCategories(prev => prev.filter(c => c.id !== id));
      addAuditLog(`DELETED SCHOLARSHIP CATEGORY`, name);
      showToast(`Category "${name}" deleted.`);
    } catch (err: any) {
      console.error('Error deleting category:', err);
      showToast(`Failed to delete category: ${err.message || 'database error'}`);
    }
  };


  return (
    <div className="h-screen bg-white flex font-sans overflow-hidden relative">
      {/* Toast Notification */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 bg-[#1A3C2E] text-white border border-[#2D5941] px-5 py-3 rounded-xl shadow-2xl flex items-center gap-2 animate-bounce">
          <svg className="w-5 h-5 text-[#E8A838]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span className="text-xs font-semibold">{toastMessage}</span>
        </div>
      )}

      {/* Sidebar Navigation */}
      <aside className={`transition-all duration-300 bg-[#1A3C2E] text-white flex flex-col justify-between shrink-0 shadow-xl border-r border-[#2D5941]/30 overflow-hidden relative ${isCollapsed ? 'w-20' : 'w-64'}`}>
        <div className="p-4 overflow-y-auto overflow-x-hidden flex-1 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          {/* Sidebar Header */}
          <div className={`flex items-center justify-between mb-6 ${isCollapsed ? 'flex-col gap-4' : ''}`}>
            <div className="flex items-center gap-3">
              <img src={LogoGoldSvg} alt="IskolarAko Logo" className="w-12 h-12 object-contain shrink-0" />
              {!isCollapsed && (
                <div>
                  <h2 className="text-lg font-bold font-serif leading-none tracking-tight">IskolarAko</h2>
                  <span className="text-[10px] text-[#9BA89F] font-semibold uppercase tracking-wider">System Admin</span>
                </div>
              )}
            </div>
            <button
              type="button"
              onClick={() => setIsCollapsed(!isCollapsed)}
              className="text-[#9BA89F] hover:text-white transition-colors cursor-pointer border-0 bg-transparent p-1"
              title={isCollapsed ? "Expand Sidebar" : "Collapse Sidebar"}
            >
              <svg className="w-5 h-5 transition-transform duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d={isCollapsed ? "M9 5l7 7-7 7" : "M15 19l-7-7 7-7"} />
              </svg>
            </button>
          </div>

          {/* Navigation Links Grouped */}
          <nav className="space-y-4">
            {/* Group 1: Operations */}
            <div className="space-y-1">
              {!isCollapsed ? (
                <button
                  type="button"
                  onClick={() => toggleGroup('operations')}
                  className="w-full flex items-center justify-between text-[10px] text-[#6C7E74] font-bold uppercase tracking-wider px-4 mb-2 hover:text-white transition-colors cursor-pointer border-0 bg-transparent"
                >
                  <span>Operations</span>
                  <svg className={`w-3 h-3 transition-transform duration-200 ${collapsedGroups.operations ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              ) : (
                <div className="border-t border-[#2D5941]/20 my-2" />
              )}
              {(!isCollapsed && collapsedGroups.operations) ? null : (
                <div className="space-y-1 animate-fade-in">
                  {renderSidebarBtn('dashboard', 'Dashboard', <LayoutDashboard className="w-4 h-4 shrink-0" />)}
                  {renderSidebarBtn('providers', 'Provider Management', <Building2 className="w-4 h-4 shrink-0" />)}
                  {renderSidebarBtn('scholarships', 'Scholarships', <GraduationCap className="w-4 h-4 shrink-0" />)}
                  {renderSidebarBtn('students', 'Scholar Management', <Users className="w-4 h-4 shrink-0" />)}
                </div>
              )}
            </div>

            {/* Group 2: Oversight */}
            <div className="space-y-1">
              {!isCollapsed ? (
                <button
                  type="button"
                  onClick={() => toggleGroup('oversight')}
                  className="w-full flex items-center justify-between text-[10px] text-[#6C7E74] font-bold uppercase tracking-wider px-4 mb-2 hover:text-white transition-colors cursor-pointer border-0 bg-transparent"
                >
                  <span>Oversight</span>
                  <svg className={`w-3 h-3 transition-transform duration-200 ${collapsedGroups.oversight ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              ) : (
                <div className="border-t border-[#2D5941]/20 my-2" />
              )}
              {(!isCollapsed && collapsedGroups.oversight) ? null : (
                <div className="space-y-1 animate-fade-in">
                  {renderSidebarBtn('applications', 'Application Monitor', <FileEdit className="w-4 h-4 shrink-0" />)}
                  {renderSidebarBtn('documents', 'Docs Oversight', <FileText className="w-4 h-4 shrink-0" />)}
                  {renderSidebarBtn('reports', 'Reports & Complaints', <Flag className="w-4 h-4 shrink-0" />)}
                  {renderSidebarBtn('funds', 'Fund Transactions', <Coins className="w-4 h-4 shrink-0" />)}
                </div>
              )}
            </div>

            {/* Group 3: Control */}
            <div className="space-y-1">
              {!isCollapsed ? (
                <button
                  type="button"
                  onClick={() => toggleGroup('control')}
                  className="w-full flex items-center justify-between text-[10px] text-[#6C7E74] font-bold uppercase tracking-wider px-4 mb-2 hover:text-white transition-colors cursor-pointer border-0 bg-transparent"
                >
                  <span>Control</span>
                  <svg className={`w-3 h-3 transition-transform duration-200 ${collapsedGroups.control ? '-rotate-90' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </button>
              ) : (
                <div className="border-t border-[#2D5941]/20 my-2" />
              )}
              {(!isCollapsed && collapsedGroups.control) ? null : (
                <div className="space-y-1 animate-fade-in">
                  {renderSidebarBtn('notifications', 'Broadcast Portal', <Megaphone className="w-4 h-4 shrink-0" />)}
                  {renderSidebarBtn('logs', 'System Audit Logs', <ScrollText className="w-4 h-4 shrink-0" />)}
                  {renderSidebarBtn('settings', 'System Settings', <Settings className="w-4 h-4 shrink-0" />)}
                  {renderSidebarBtn('profile', 'Profile Settings', <User className="w-4 h-4 shrink-0" />)}
                </div>
              )}
            </div>
          </nav>
        </div>

        {/* Footer Profile / Logout */}
        <div className={`p-4 border-t border-[#2D5941]/30 ${isCollapsed ? 'flex flex-col items-center gap-4' : 'space-y-4'}`}>
          {!isCollapsed ? (
            <>
              <div className="flex items-center gap-3 p-3 rounded-2xl bg-white/5 border border-white/10">
                <div className="w-8 h-8 rounded-full bg-[#2D5941] flex items-center justify-center font-bold text-white text-xs shrink-0">
                  {profile ? `${profile.firstName.charAt(0)}${profile.lastName.charAt(0)}`.toUpperCase() : 'AD'}
                </div>
                <div className="min-w-0 flex-1">
                  <h4 className="text-xs font-semibold truncate text-white">
                    {profile ? `${profile.firstName} ${profile.lastName}` : 'Loading...'}
                  </h4>
                  <p className="text-[10px] text-[#9BA89F] truncate">
                    {profile ? (profile.role === 'admin' ? 'System Admin' : profile.role) : 'Loading...'}
                  </p>
                </div>
              </div>
              <button
                onClick={onLogout}
                className="w-full bg-[#B34040] hover:bg-[#8E2F2F] text-white text-xs font-bold py-2.5 rounded-xl shadow-md cursor-pointer transition-colors border-0"
              >
                Sign Out
              </button>
            </>
          ) : (
            <>
              <div
                className="w-8 h-8 rounded-full bg-[#2D5941] flex items-center justify-center font-bold text-white text-xs shrink-0"
                title={profile ? `${profile.firstName} ${profile.lastName} - System Admin` : 'Admin'}
              >
                {profile ? `${profile.firstName.charAt(0)}${profile.lastName.charAt(0)}`.toUpperCase() : 'AD'}
              </div>
              <button
                onClick={onLogout}
                className="text-[#9BA89F] hover:text-white cursor-pointer border-0 bg-transparent flex items-center justify-center"
                title="Sign Out"
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                </svg>
              </button>
            </>
          )}
        </div>

      </aside>

      {/* Main Content Area */}
      <main className="flex-1 p-8 overflow-y-auto w-full space-y-6">

        {/* Module Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-extrabold text-[#1A3C2E] font-serif capitalize">
              {activeTab === 'logs' ? 'System Audit Logs' : activeTab === 'funds' ? 'Fund Release Monitoring' : activeTab === 'providers' ? 'Provider Management' : activeTab === 'profile' ? 'Profile Settings' : activeTab}
            </h1>
            <p className="text-xs text-[#6C6C70] mt-1">
              System Administration, trust moderation, and oversight metrics.
            </p>
          </div>
          {activeTab === 'dashboard' && (
            <span className="text-xs font-bold px-3 py-1.5 rounded-full bg-[#EBF5EE] text-[#2D5941] border border-[#2D5941]/20">
              Platform Status: Operational
            </span>
          )}
        </div>

        {activeTab === 'dashboard' && (
          <AdminDashboardTab
            setActiveTab={setActiveTab}
            auditLogs={auditLogs}
            totalStudents={dashboardMetrics.totalStudents}
            totalProviders={dashboardMetrics.totalProviders}
            verifiedProviders={dashboardMetrics.verifiedProviders}
            pendingVerifications={dashboardMetrics.pendingVerifications}
            activeScholarships={dashboardMetrics.activeScholarships}
            pendingApplications={dashboardMetrics.pendingApplications}
            approvedScholars={dashboardMetrics.approvedScholars}
            flaggedReports={dashboardMetrics.flaggedReports}
            totalReleased={dashboardMetrics.totalReleased}
            pendingDisbursements={dashboardMetrics.pendingDisbursements}
          />
        )}

        {activeTab === 'providers' && (
          <AdminProvidersTab
            providerFilter={providerFilter}
            setProviderFilter={setProviderFilter}
            providers={providers}
            selectedProvider={selectedProvider}
            setSelectedProvider={setSelectedProvider}
            providerRequirementsMap={providerRequirementsMap}
            isChecklistCollapsed={isChecklistCollapsed}
            setIsChecklistCollapsed={setIsChecklistCollapsed}
            isOversightCollapsed={isOversightCollapsed}
            setIsOversightCollapsed={setIsOversightCollapsed}
            loadingPrograms={loadingPrograms}
            providerPrograms={providerPrograms}
            setSelectedScholarshipDetails={setSelectedScholarshipDetails}
            setActiveTab={setActiveTab}
            handleVerifyProvider={handleVerifyProvider}
            handleReactivateProvider={handleReactivateProvider}
            onUpdateProviderDocs={handleUpdateProviderDocs}
          />
        )}

        {activeTab === 'scholarships' && (
          <AdminScholarshipsTab
            loadingScholarships={loadingScholarships}
            scholarships={scholarships}
            setSelectedScholarshipDetails={setSelectedScholarshipDetails}
            handleScholarshipAction={handleScholarshipAction}
          />
        )}

        {activeTab === 'students' && (
          <AdminStudentsTab
            searchQuery={searchQuery}
            setSearchQuery={setSearchQuery}
            loadingScholars={loadingScholars}
            students={students}
            selectedStudent={selectedStudent}
            setSelectedStudent={setSelectedStudent}
            handleStudentStatus={handleStudentStatus}
          />
        )}

        {activeTab === 'applications' && <AdminApplicationsTab />}

        {activeTab === 'documents' && <AdminDocumentsTab showToast={showToast} />}

        {activeTab === 'reports' && (
          <AdminReportsTab
            reports={reports}
            handleReportAction={handleReportAction}
            showToast={showToast}
            providers={providers}
            scholarships={scholarships}
            students={students}
            auditLogs={auditLogs}
          />
        )}

        {activeTab === 'funds' && <AdminFundsTab />}

        {activeTab === 'notifications' && (
          <AdminNotificationsTab
            handleSendAnnouncement={handleSendAnnouncement}
            announcementTarget={announcementTarget}
            setAnnouncementTarget={setAnnouncementTarget}
            announcementTitle={announcementTitle}
            setAnnouncementTitle={setAnnouncementTitle}
            announcementBody={announcementBody}
            setAnnouncementBody={setAnnouncementBody}
            adminBroadcasts={adminBroadcasts}
            isSendingAnnouncement={isSendingAnnouncement}
            onDeleteBroadcast={handleDeleteAdminBroadcast}
            providers={providers}
            students={students}
            selectedTargetProviderId={selectedTargetProviderId}
            setSelectedTargetProviderId={setSelectedTargetProviderId}
            selectedTargetUserId={selectedTargetUserId}
            setSelectedTargetUserId={setSelectedTargetUserId}
          />
        )}

        {activeTab === 'logs' && <AdminLogsTab auditLogs={auditLogs} />}

        {activeTab === 'settings' && (
          <AdminSettingsTab
            categories={categories}
            showAddCategoryForm={showAddCategoryForm}
            setShowAddCategoryForm={setShowAddCategoryForm}
            editingCategoryId={editingCategoryId}
            setEditingCategoryId={setEditingCategoryId}
            editingCategoryName={editingCategoryName}
            setEditingCategoryName={setEditingCategoryName}
            categoryInputs={categoryInputs}
            setCategoryInputs={setCategoryInputs}
            handleSaveEditCategory={handleSaveEditCategory}
            handleStartEditCategory={handleStartEditCategory}
            handleDeleteCategory={handleDeleteCategory}
            handleSaveMultipleCategories={handleSaveMultipleCategories}
            maintenanceMode={maintenanceMode}
            setMaintenanceMode={setMaintenanceMode}
            addAuditLog={addAuditLog}
            showToast={showToast}
            selectedProviderType={selectedProviderType}
            setSelectedProviderType={setSelectedProviderType}
            reqItems={reqItems}
            editingReqIndex={editingReqIndex}
            setEditingReqIndex={setEditingReqIndex}
            editReqName={editReqName}
            setEditReqName={setEditReqName}
            editReqDesc={editReqDesc}
            setEditReqDesc={setEditReqDesc}
            editReqRequired={editReqRequired}
            setEditReqRequired={setEditReqRequired}
            handleSaveEditRequirement={handleSaveEditRequirement}
            handleStartEditRequirement={handleStartEditRequirement}
            handleRemoveRequirement={handleRemoveRequirement}
            handleAddRequirement={handleAddRequirement}
            newReqProviderTypes={newReqProviderTypes}
            setNewReqProviderTypes={setNewReqProviderTypes}
            newReqName={newReqName}
            setNewReqName={setNewReqName}
            newReqDesc={newReqDesc}
            setNewReqDesc={setNewReqDesc}
            newReqRequired={newReqRequired}
            setNewReqRequired={setNewReqRequired}
            isSavingReq={isSavingReq}
            handleSaveRequirements={handleSaveRequirements}
          />
        )}

        {activeTab === 'profile' && (
          <ProfileSettingsTab
            showToast={showToast}
            onProfileUpdated={(updated) => setProfile(prev => prev ? { ...prev, ...updated } : prev)}
          />
        )}
      </main>

      {/* Reject Remarks Modal */}
      <RejectRemarksModal
        isOpen={isRejectModalOpen}
        rejectRemarks={rejectRemarks}
        setRejectRemarks={setRejectRemarks}
        onClose={() => setIsRejectModalOpen(false)}
        onConfirm={() => handleVerifyProvider(rejectProviderId, 'Suspended', rejectRemarks)}
        mode={providers.find(p => p.id === rejectProviderId)?.status === 'Verified' ? 'suspend' : 'reject'}
      />

      {/* Scholarship View Details Modal for Admin */}
      <AdminProgramDetailsModal
        program={selectedScholarshipDetails}
        onClose={() => setSelectedScholarshipDetails(null)}
      />

      {/* Scholarship Rejection Remarks Modal */}
      <RejectScholarshipModal
        isOpen={isRejectScholarshipModalOpen}
        remarks={rejectScholarshipRemarks}
        setRemarks={setRejectScholarshipRemarks}
        onClose={() => { setIsRejectScholarshipModalOpen(false); setRejectScholarshipId(null); setRejectScholarshipRemarks(''); }}
        onConfirm={handleConfirmRejectScholarship}
      />
    </div>
  );
};
