import React, { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'
import { useAuth } from './AuthContext'

interface Company {
  id: string
  name: string
  slug: string
  logo_url: string | null
  status: 'active' | 'trial' | 'delinquent' | 'suspended'
}

interface CompanyWithRole extends Company {
  userRole: 'admin' | 'user' | 'super_admin'
}

interface CompanyContextType {
  companies: CompanyWithRole[]
  currentCompany: CompanyWithRole | null
  userRole: 'admin' | 'user' | 'super_admin' | null
  loading: boolean
  switchCompany: (companyId: string) => void
  refreshCompanies: () => Promise<void>
}

const CompanyContext = createContext<CompanyContextType | undefined>(undefined)

export function useCompany() {
  const context = useContext(CompanyContext)
  if (context === undefined) {
    throw new Error('useCompany must be used within a CompanyProvider')
  }
  return context
}

interface CompanyProviderProps {
  children: React.ReactNode
}

export function CompanyProvider({ children }: CompanyProviderProps) {
  const { user } = useAuth()
  const [companies, setCompanies] = useState<CompanyWithRole[]>([])
  const [currentCompany, setCurrentCompany] = useState<CompanyWithRole | null>(null)
  const [userRole, setUserRole] = useState<'admin' | 'user' | 'super_admin' | null>(null)
  const [loading, setLoading] = useState(true)

  const fetchCompanies = async () => {
    if (!user) {
      setCompanies([])
      setCurrentCompany(null)
      setUserRole(null)
      setLoading(false)
      return
    }

    try {
      // Fetch companies the user is a member of
      const { data: memberData, error: memberError } = await supabase
        .from('company_members')
        .select(`
          company_id,
          role,
          companies (
            id,
            name,
            slug,
            logo_url,
            status
          )
        `)
        .eq('user_id', user.id)

      if (memberError) throw memberError

      const companiesData: CompanyWithRole[] = memberData
        ?.map(member => {
          const company = member.companies as any
          if (company) {
            return {
              id: company.id,
              name: company.name,
              slug: company.slug,
              logo_url: company.logo_url,
              status: company.status,
              userRole: member.role
            } as CompanyWithRole
          }
          return null
        })
        .filter((company): company is CompanyWithRole => company !== null) || []

      setCompanies(companiesData)

      // Set current company from localStorage or default to first company
      const savedCompanyId = localStorage.getItem('currentCompanyId')
      let targetCompany = companiesData.find(c => c.id === savedCompanyId) || companiesData[0] || null

      if (targetCompany) {
        setCurrentCompany(targetCompany)
        setUserRole(targetCompany.userRole)
        localStorage.setItem('currentCompanyId', targetCompany.id)
      } else {
        setCurrentCompany(null)
        setUserRole(null)
        localStorage.removeItem('currentCompanyId')
      }
    } catch (error) {
      console.error('Error fetching companies:', error)
    } finally {
      setLoading(false)
    }
  }

  const switchCompany = (companyId: string) => {
    const company = companies.find(c => c.id === companyId)
    if (company) {
      setCurrentCompany(company)
      setUserRole(company.userRole)
      localStorage.setItem('currentCompanyId', companyId)
    }
  }

  const refreshCompanies = async () => {
    setLoading(true)
    await fetchCompanies()
  }

  useEffect(() => {
    fetchCompanies()
  }, [user])

  const value = {
    companies,
    currentCompany,
    userRole,
    loading,
    switchCompany,
    refreshCompanies,
  }

  return <CompanyContext.Provider value={value}>{children}</CompanyContext.Provider>
}
