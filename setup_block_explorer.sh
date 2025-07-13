#!/bin/bash

# Sui Block Explorer Setup Script
# Creates a custom block explorer for the modified Sui network

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Configuration
EXPLORER_DIR="sui-explorer-custom"
EXPLORER_PORT="3000"
API_PORT="9000"
WS_PORT="9001"

setup_explorer_environment() {
    print_status "Setting up block explorer environment..."
    
    # Create explorer directory
    mkdir -p $EXPLORER_DIR
    cd $EXPLORER_DIR
    
    # Initialize package.json for custom explorer
    cat > package.json << EOF
{
  "name": "sui-custom-explorer",
  "version": "1.0.0",
  "description": "Custom Sui Block Explorer with Modified Payout Display",
  "main": "index.js",
  "scripts": {
    "dev": "next dev -p $EXPLORER_PORT",
    "build": "next build",
    "start": "next start -p $EXPLORER_PORT",
    "lint": "next lint",
    "type-check": "tsc --noEmit"
  },
  "dependencies": {
    "next": "^14.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@types/node": "^20.0.0",
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "typescript": "^5.0.0",
    "tailwindcss": "^3.3.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "@headlessui/react": "^1.7.0",
    "@heroicons/react": "^2.0.0",
    "axios": "^1.6.0",
    "date-fns": "^2.30.0",
    "recharts": "^2.8.0",
    "react-query": "^3.39.0",
    "ws": "^8.14.0",
    "@types/ws": "^8.5.0"
  },
  "devDependencies": {
    "eslint": "^8.0.0",
    "eslint-config-next": "^14.0.0",
    "@tailwindcss/forms": "^0.5.0",
    "@tailwindcss/typography": "^0.5.0"
  }
}
EOF

    print_success "Package.json created"
}

create_explorer_config() {
    print_status "Creating explorer configuration..."
    
    # Create Next.js config
    cat > next.config.js << EOF
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  env: {
    NEXT_PUBLIC_RPC_URL: process.env.NEXT_PUBLIC_RPC_URL || 'http://localhost:$API_PORT',
    NEXT_PUBLIC_WS_URL: process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:$WS_PORT',
    NEXT_PUBLIC_NETWORK: process.env.NEXT_PUBLIC_NETWORK || 'custom',
    NEXT_PUBLIC_NETWORK_NAME: process.env.NEXT_PUBLIC_NETWORK_NAME || 'Custom Sui Network',
    NEXT_PUBLIC_FAUCET_URL: process.env.NEXT_PUBLIC_FAUCET_URL || 'http://localhost:5003/gas',
  },
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: 'http://localhost:$API_PORT/:path*',
      },
    ]
  },
}

module.exports = nextConfig
EOF

    # Create environment file
    cat > .env.local << EOF
# Sui Custom Network Configuration
NEXT_PUBLIC_RPC_URL=http://localhost:$API_PORT
NEXT_PUBLIC_WS_URL=ws://localhost:$WS_PORT
NEXT_PUBLIC_NETWORK=custom
NEXT_PUBLIC_NETWORK_NAME=Custom Sui Network (Modified Payouts)
NEXT_PUBLIC_FAUCET_URL=http://localhost:5003/gas
NEXT_PUBLIC_ENABLE_DEV_TOOLS=true

# Custom payout information
NEXT_PUBLIC_DELEGATOR_RATE=1.0
NEXT_PUBLIC_VALIDATOR_RATE=1.5
NEXT_PUBLIC_PAYOUT_INFO_ENABLED=true
EOF

    print_success "Explorer configuration created"
}

create_tailwind_config() {
    print_status "Setting up Tailwind CSS..."
    
    cat > tailwind.config.js << EOF
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        'sui-blue': '#4da2ff',
        'sui-dark': '#1a1a1a',
        'success': '#10b981',
        'warning': '#f59e0b',
        'error': '#ef4444',
      },
      animation: {
        'pulse-slow': 'pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      }
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
}
EOF

    cat > postcss.config.js << EOF
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

    print_success "Tailwind CSS configuration created"
}

create_typescript_config() {
    print_status "Setting up TypeScript configuration..."
    
    cat > tsconfig.json << EOF
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "baseUrl": ".",
    "paths": {
      "@/*": ["./*"],
      "@/components/*": ["./components/*"],
      "@/lib/*": ["./lib/*"],
      "@/types/*": ["./types/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

    print_success "TypeScript configuration created"
}

create_directory_structure() {
    print_status "Creating directory structure..."
    
    mkdir -p {components,lib,types,pages/api,public,styles}
    mkdir -p components/{layout,ui,charts,validators}
    mkdir -p lib/{api,utils,hooks}
    
    print_success "Directory structure created"
}

create_types() {
    print_status "Creating TypeScript types..."
    
    cat > types/sui.ts << 'EOF'
// Sui Network Types for Custom Explorer

export interface SuiTransaction {
  digest: string;
  timestamp: number;
  sender: string;
  gasUsed: number;
  gasPrice: number;
  status: 'success' | 'failure';
  effects: any;
}

export interface SuiValidator {
  address: string;
  name: string;
  description: string;
  imageUrl: string;
  projectUrl: string;
  stake: number;
  votingPower: number;
  commissionRate: number;
  gasPrice: number;
  nextEpochStake: number;
  delegatedStake: number;
  ownStake: number;
  apy: number;
  isActive: boolean;
}

export interface SuiEpoch {
  epoch: number;
  startTime: number;
  endTime: number;
  totalStake: number;
  totalRewards: number;
  validatorCount: number;
  transactionCount: number;
}

export interface SuiReward {
  epoch: number;
  validator: string;
  delegatorRewards: number;
  validatorRewards: number;
  totalRewards: number;
  delegatorRate: number; // 1.0% for our custom network
  validatorRate: number; // 1.5% for our custom network
}

export interface NetworkStats {
  currentEpoch: number;
  totalTransactions: number;
  totalStake: number;
  totalValidators: number;
  tps: number;
  gasPrice: number;
  delegatorDailyRate: number;
  validatorDailyRate: number;
}

export interface AccountBalance {
  address: string;
  balance: number;
  objects: any[];
}
EOF

    print_success "TypeScript types created"
}

create_api_utilities() {
    print_status "Creating API utilities..."
    
    cat > lib/api/sui-client.ts << 'EOF'
// Sui API Client for Custom Network

import axios from 'axios';

const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || 'http://localhost:9000';
const WS_URL = process.env.NEXT_PUBLIC_WS_URL || 'ws://localhost:9001';

export class SuiApiClient {
  private rpcUrl: string;
  private wsUrl: string;

  constructor() {
    this.rpcUrl = RPC_URL;
    this.wsUrl = WS_URL;
  }

  async rpcCall(method: string, params: any[] = []) {
    try {
      const response = await axios.post(this.rpcUrl, {
        jsonrpc: '2.0',
        id: Date.now(),
        method,
        params,
      }, {
        headers: {
          'Content-Type': 'application/json',
        },
      });
      
      if (response.data.error) {
        throw new Error(response.data.error.message);
      }
      
      return response.data.result;
    } catch (error) {
      console.error(`RPC call failed for ${method}:`, error);
      throw error;
    }
  }

  // Network information
  async getNetworkInfo() {
    return this.rpcCall('sui_getChainIdentifier');
  }

  async getCurrentEpoch() {
    return this.rpcCall('suix_getCurrentEpoch');
  }

  // Transaction methods
  async getTransaction(digest: string) {
    return this.rpcCall('sui_getTransactionBlock', [
      digest,
      {
        showInput: true,
        showRawInput: false,
        showEffects: true,
        showEvents: true,
        showObjectChanges: true,
        showBalanceChanges: true,
      },
    ]);
  }

  async getTransactions(limit: number = 20, cursor?: string) {
    return this.rpcCall('suix_queryTransactionBlocks', [
      { limit, cursor },
      null,
      false,
    ]);
  }

  // Validator methods
  async getValidators() {
    return this.rpcCall('suix_getLatestSuiSystemState');
  }

  async getValidatorApy() {
    return this.rpcCall('suix_getValidatorsApy');
  }

  // Account methods
  async getBalance(address: string) {
    return this.rpcCall('suix_getBalance', [address]);
  }

  async getAllBalances(address: string) {
    return this.rpcCall('suix_getAllBalances', [address]);
  }

  async getOwnedObjects(address: string) {
    return this.rpcCall('suix_getOwnedObjects', [
      address,
      {
        showType: true,
        showOwner: true,
        showPreviousTransaction: true,
        showDisplay: false,
        showContent: false,
        showBcs: false,
        showStorageRebate: true,
      },
    ]);
  }

  // Custom methods for our modified payout system
  async getCustomRewardInfo(epoch: number) {
    // This would be a custom endpoint for our modified system
    // For now, we'll calculate based on stake amounts
    try {
      const systemState = await this.getValidators();
      const validators = systemState?.activeValidators || [];
      
      return validators.map((validator: any) => ({
        address: validator.suiAddress,
        stake: parseInt(validator.stakingPoolSuiBalance),
        delegatorRewards: Math.floor(parseInt(validator.stakingPoolSuiBalance) * 0.01), // 1% daily
        validatorRewards: Math.floor(parseInt(validator.stakingPoolSuiBalance) * 0.015), // 1.5% daily
        epoch,
      }));
    } catch (error) {
      console.error('Error getting custom reward info:', error);
      return [];
    }
  }
}

export const suiClient = new SuiApiClient();
EOF

    cat > lib/utils/format.ts << 'EOF'
// Formatting utilities for Sui values

export const MIST_PER_SUI = 1_000_000_000;

export function formatSui(mist: number | string, decimals: number = 2): string {
  const sui = typeof mist === 'string' ? parseInt(mist) : mist;
  return (sui / MIST_PER_SUI).toFixed(decimals);
}

export function formatMist(mist: number | string): string {
  const value = typeof mist === 'string' ? parseInt(mist) : mist;
  return value.toLocaleString();
}

export function formatAddress(address: string, length: number = 8): string {
  if (address.length <= length * 2) return address;
  return `${address.slice(0, length)}...${address.slice(-length)}`;
}

export function formatTimestamp(timestamp: number): string {
  return new Date(timestamp).toLocaleString();
}

export function formatPercentage(value: number, decimals: number = 2): string {
  return `${value.toFixed(decimals)}%`;
}

export function calculateApy(dailyRate: number): number {
  // Compound daily rate to annual percentage yield
  return (Math.pow(1 + dailyRate / 100, 365) - 1) * 100;
}
EOF

    print_success "API utilities created"
}

create_components() {
    print_status "Creating React components..."
    
    # Layout component
    cat > components/layout/Layout.tsx << 'EOF'
import React from 'react';
import Head from 'next/head';
import { Navbar } from './Navbar';
import { Footer } from './Footer';

interface LayoutProps {
  children: React.ReactNode;
  title?: string;
}

export const Layout: React.FC<LayoutProps> = ({ children, title = 'Sui Explorer' }) => {
  return (
    <>
      <Head>
        <title>{title}</title>
        <meta name="description" content="Custom Sui Network Explorer with Modified Payout Distribution" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <link rel="icon" href="/favicon.ico" />
      </Head>
      <div className="min-h-screen bg-gray-50 flex flex-col">
        <Navbar />
        <main className="flex-1 container mx-auto px-4 py-8">
          {children}
        </main>
        <Footer />
      </div>
    </>
  );
};
EOF

    # Navbar component
    cat > components/layout/Navbar.tsx << 'EOF'
import React from 'react';
import Link from 'next/link';

export const Navbar: React.FC = () => {
  return (
    <nav className="bg-white shadow-sm border-b">
      <div className="container mx-auto px-4">
        <div className="flex justify-between items-center h-16">
          <Link href="/" className="flex items-center space-x-2">
            <div className="w-8 h-8 bg-sui-blue rounded-lg flex items-center justify-center">
              <span className="text-white font-bold">S</span>
            </div>
            <span className="text-xl font-bold text-gray-900">Sui Explorer</span>
            <span className="text-sm text-gray-500 bg-yellow-100 px-2 py-1 rounded">
              Custom Payouts
            </span>
          </Link>
          
          <div className="flex space-x-6">
            <Link href="/" className="text-gray-700 hover:text-sui-blue transition-colors">
              Home
            </Link>
            <Link href="/validators" className="text-gray-700 hover:text-sui-blue transition-colors">
              Validators
            </Link>
            <Link href="/transactions" className="text-gray-700 hover:text-sui-blue transition-colors">
              Transactions
            </Link>
            <Link href="/epochs" className="text-gray-700 hover:text-sui-blue transition-colors">
              Epochs
            </Link>
            <Link href="/faucet" className="text-gray-700 hover:text-sui-blue transition-colors">
              Faucet
            </Link>
          </div>
        </div>
      </div>
    </nav>
  );
};
EOF

    # Footer component
    cat > components/layout/Footer.tsx << 'EOF'
import React from 'react';

export const Footer: React.FC = () => {
  return (
    <footer className="bg-white border-t">
      <div className="container mx-auto px-4 py-6">
        <div className="flex flex-col md:flex-row justify-between items-center">
          <div className="text-gray-600 text-sm">
            © 2024 Custom Sui Network Explorer. Modified payout distribution: 1% delegators, 1.5% validators.
          </div>
          <div className="flex space-x-4 mt-4 md:mt-0">
            <a href="https://sui.io" target="_blank" rel="noopener noreferrer" 
               className="text-gray-500 hover:text-sui-blue transition-colors">
              Official Sui
            </a>
            <a href="https://github.com/MystenLabs/sui" target="_blank" rel="noopener noreferrer"
               className="text-gray-500 hover:text-sui-blue transition-colors">
              GitHub
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
};
EOF

    # Stats card component
    cat > components/ui/StatsCard.tsx << 'EOF'
import React from 'react';

interface StatsCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  icon?: React.ReactNode;
  trend?: {
    value: number;
    isPositive: boolean;
  };
}

export const StatsCard: React.FC<StatsCardProps> = ({ 
  title, 
  value, 
  subtitle, 
  icon, 
  trend 
}) => {
  return (
    <div className="bg-white rounded-lg shadow p-6">
      <div className="flex items-center justify-between">
        <div>
          <p className="text-sm font-medium text-gray-600">{title}</p>
          <p className="text-2xl font-semibold text-gray-900">{value}</p>
          {subtitle && (
            <p className="text-sm text-gray-500">{subtitle}</p>
          )}
          {trend && (
            <div className={`text-sm ${trend.isPositive ? 'text-green-600' : 'text-red-600'}`}>
              {trend.isPositive ? '↗' : '↘'} {Math.abs(trend.value)}%
            </div>
          )}
        </div>
        {icon && (
          <div className="text-sui-blue">
            {icon}
          </div>
        )}
      </div>
    </div>
  );
};
EOF

    print_success "React components created"
}

create_pages() {
    print_status "Creating main pages..."
    
    # Create styles
    cat > styles/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  html {
    font-family: system-ui, sans-serif;
  }
}

@layer utilities {
  .animate-pulse-slow {
    animation: pulse 3s cubic-bezier(0.4, 0, 0.6, 1) infinite;
  }
}
EOF

    # Main index page
    cat > pages/index.tsx << 'EOF'
import React, { useState, useEffect } from 'react';
import { Layout } from '@/components/layout/Layout';
import { StatsCard } from '@/components/ui/StatsCard';
import { suiClient } from '@/lib/api/sui-client';
import { formatSui, formatPercentage, calculateApy } from '@/lib/utils/format';

export default function Home() {
  const [stats, setStats] = useState({
    totalValidators: 0,
    totalStake: 0,
    currentEpoch: 0,
    delegatorRate: 1.0,
    validatorRate: 1.5,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        const [epochData, systemState] = await Promise.all([
          suiClient.getCurrentEpoch(),
          suiClient.getValidators(),
        ]);

        const validators = systemState?.activeValidators || [];
        const totalStake = validators.reduce((sum: number, v: any) => 
          sum + parseInt(v.stakingPoolSuiBalance || 0), 0);

        setStats({
          totalValidators: validators.length,
          totalStake,
          currentEpoch: epochData?.epoch || 0,
          delegatorRate: 1.0,
          validatorRate: 1.5,
        });
      } catch (error) {
        console.error('Error fetching stats:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
    const interval = setInterval(fetchStats, 30000); // Update every 30 seconds
    return () => clearInterval(interval);
  }, []);

  const delegatorApy = calculateApy(stats.delegatorRate);
  const validatorApy = calculateApy(stats.validatorRate);

  return (
    <Layout title="Custom Sui Network Explorer">
      <div className="space-y-8">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-4xl font-bold text-gray-900 mb-4">
            Custom Sui Network Explorer
          </h1>
          <p className="text-lg text-gray-600 max-w-2xl mx-auto">
            Blockchain explorer for a custom Sui network with modified payout distribution.
            Delegators earn <span className="font-semibold text-sui-blue">1% daily</span>,
            validators earn <span className="font-semibold text-sui-blue">1.5% daily</span>.
          </p>
        </div>

        {/* Modified Payout Info Banner */}
        <div className="bg-gradient-to-r from-sui-blue to-blue-600 text-white rounded-lg p-6">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-xl font-semibold mb-2">Modified Payout Distribution</h2>
              <p className="text-blue-100">
                This network implements custom daily percentage rewards instead of traditional gas fee distribution.
              </p>
            </div>
            <div className="text-right">
              <div className="text-2xl font-bold">{formatPercentage(stats.delegatorRate)}</div>
              <div className="text-blue-200">Delegator Daily Rate</div>
              <div className="text-2xl font-bold mt-2">{formatPercentage(stats.validatorRate)}</div>
              <div className="text-blue-200">Validator Daily Rate</div>
            </div>
          </div>
        </div>

        {/* Network Stats */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <StatsCard
            title="Current Epoch"
            value={loading ? '...' : stats.currentEpoch}
            subtitle="24 hour epochs"
          />
          <StatsCard
            title="Total Validators"
            value={loading ? '...' : stats.totalValidators}
            subtitle="Active validators"
          />
          <StatsCard
            title="Total Stake"
            value={loading ? '...' : `${formatSui(stats.totalStake)} SUI`}
            subtitle="Network staked amount"
          />
          <StatsCard
            title="Delegator APY"
            value={loading ? '...' : formatPercentage(delegatorApy)}
            subtitle={`${formatPercentage(stats.delegatorRate)} daily`}
          />
        </div>

        {/* Validator APY Comparison */}
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">
            Annual Percentage Yield (APY) Comparison
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div className="text-center p-4 bg-green-50 rounded-lg">
              <div className="text-2xl font-bold text-green-600">
                {formatPercentage(delegatorApy)}
              </div>
              <div className="text-green-700 font-medium">Delegator APY</div>
              <div className="text-sm text-green-600 mt-1">
                {formatPercentage(stats.delegatorRate)} daily compound
              </div>
            </div>
            <div className="text-center p-4 bg-blue-50 rounded-lg">
              <div className="text-2xl font-bold text-blue-600">
                {formatPercentage(validatorApy)}
              </div>
              <div className="text-blue-700 font-medium">Validator APY</div>
              <div className="text-sm text-blue-600 mt-1">
                {formatPercentage(stats.validatorRate)} daily compound
              </div>
            </div>
          </div>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <a href="/validators" 
             className="block p-6 bg-white rounded-lg shadow hover:shadow-md transition-shadow">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">View Validators</h3>
            <p className="text-gray-600">Explore active validators and their performance</p>
          </a>
          <a href="/transactions" 
             className="block p-6 bg-white rounded-lg shadow hover:shadow-md transition-shadow">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Recent Transactions</h3>
            <p className="text-gray-600">Browse the latest network transactions</p>
          </a>
          <a href="/faucet" 
             className="block p-6 bg-white rounded-lg shadow hover:shadow-md transition-shadow">
            <h3 className="text-lg font-semibold text-gray-900 mb-2">Test Faucet</h3>
            <p className="text-gray-600">Get test SUI tokens for development</p>
          </a>
        </div>
      </div>
    </Layout>
  );
}
EOF

    # Validators page
    cat > pages/validators.tsx << 'EOF'
import React, { useState, useEffect } from 'react';
import { Layout } from '@/components/layout/Layout';
import { suiClient } from '@/lib/api/sui-client';
import { formatSui, formatAddress, formatPercentage } from '@/lib/utils/format';

export default function Validators() {
  const [validators, setValidators] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchValidators = async () => {
      try {
        const systemState = await suiClient.getValidators();
        const validatorsList = systemState?.activeValidators || [];
        
        // Add custom payout calculations
        const enrichedValidators = validatorsList.map((validator: any) => {
          const stake = parseInt(validator.stakingPoolSuiBalance || 0);
          return {
            ...validator,
            dailyDelegatorRewards: Math.floor(stake * 0.01), // 1% daily
            dailyValidatorRewards: Math.floor(stake * 0.015), // 1.5% daily
          };
        });
        
        setValidators(enrichedValidators);
      } catch (error) {
        console.error('Error fetching validators:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchValidators();
  }, []);

  if (loading) {
    return (
      <Layout title="Validators - Sui Explorer">
        <div className="text-center py-12">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-sui-blue mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading validators...</p>
        </div>
      </Layout>
    );
  }

  return (
    <Layout title="Validators - Sui Explorer">
      <div className="space-y-6">
        <div className="flex justify-between items-center">
          <h1 className="text-3xl font-bold text-gray-900">Active Validators</h1>
          <div className="text-sm text-gray-600">
            {validators.length} validators active
          </div>
        </div>

        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
          <h3 className="text-sm font-medium text-yellow-800 mb-1">Custom Payout Information</h3>
          <p className="text-sm text-yellow-700">
            This network uses modified payout distribution: delegators earn 1% daily, validators earn 1.5% daily.
          </p>
        </div>

        <div className="bg-white shadow overflow-hidden rounded-lg">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Validator
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Stake
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Commission
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Daily Rewards (1%)
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Validator Bonus (1.5%)
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {validators.map((validator: any, index) => (
                <tr key={validator.suiAddress} className={index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="flex-shrink-0 h-10 w-10">
                        <div className="h-10 w-10 rounded-full bg-sui-blue flex items-center justify-center">
                          <span className="text-white font-medium">
                            {(validator.metadata?.name || 'V')[0].toUpperCase()}
                          </span>
                        </div>
                      </div>
                      <div className="ml-4">
                        <div className="text-sm font-medium text-gray-900">
                          {validator.metadata?.name || 'Unnamed Validator'}
                        </div>
                        <div className="text-sm text-gray-500">
                          {formatAddress(validator.suiAddress)}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {formatSui(validator.stakingPoolSuiBalance)} SUI
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    {formatPercentage(validator.commissionRate / 100)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-green-600 font-medium">
                    {formatSui(validator.dailyDelegatorRewards)} SUI
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-blue-600 font-medium">
                    {formatSui(validator.dailyValidatorRewards)} SUI
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </Layout>
  );
}
EOF

    # Create additional basic pages
    cat > pages/_app.tsx << 'EOF'
import type { AppProps } from 'next/app'
import '@/styles/globals.css'

export default function App({ Component, pageProps }: AppProps) {
  return <Component {...pageProps} />
}
EOF

    cat > pages/404.tsx << 'EOF'
import { Layout } from '@/components/layout/Layout';

export default function Custom404() {
  return (
    <Layout title="Page Not Found - Sui Explorer">
      <div className="text-center py-12">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">404 - Page Not Found</h1>
        <p className="text-gray-600 mb-8">The page you're looking for doesn't exist.</p>
        <a href="/" className="bg-sui-blue text-white px-6 py-3 rounded-lg hover:bg-blue-600 transition-colors">
          Go Home
        </a>
      </div>
    </Layout>
  );
}
EOF

    print_success "Main pages created"
}

install_dependencies() {
    print_status "Installing dependencies..."
    
    if command -v pnpm &> /dev/null; then
        pnpm install
    elif command -v yarn &> /dev/null; then
        yarn install
    else
        npm install
    fi
    
    print_success "Dependencies installed"
}

create_build_script() {
    print_status "Creating build and deployment scripts..."
    
    cat > build.sh << 'EOF'
#!/bin/bash
# Build script for Sui Explorer

echo "Building Sui Custom Explorer..."

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    if command -v pnpm &> /dev/null; then
        pnpm install
    elif command -v yarn &> /dev/null; then
        yarn install
    else
        npm install
    fi
fi

# Build the application
echo "Building application..."
if command -v pnpm &> /dev/null; then
    pnpm build
elif command -v yarn &> /dev/null; then
    yarn build
else
    npm run build
fi

echo "Build complete! Run 'npm start' to serve the application."
EOF

    cat > start.sh << 'EOF'
#!/bin/bash
# Start script for Sui Explorer

echo "Starting Sui Custom Explorer on port 3000..."

if command -v pnpm &> /dev/null; then
    pnpm start
elif command -v yarn &> /dev/null; then
    yarn start
else
    npm start
fi
EOF

    chmod +x build.sh start.sh
    
    print_success "Build scripts created"
}

# Main function
main() {
    print_status "Setting up Custom Sui Block Explorer..."
    
    setup_explorer_environment
    create_explorer_config
    create_tailwind_config
    create_typescript_config
    create_directory_structure
    create_types
    create_api_utilities
    create_components
    create_pages
    install_dependencies
    create_build_script
    
    print_success "==============================================="
    print_success "🎉 Block Explorer Setup Complete! 🎉"
    print_success "==============================================="
    echo ""
    print_status "Explorer Features:"
    echo "  • Custom payout information display"
    echo "  • Real-time validator statistics"
    echo "  • Modified reward calculations"
    echo "  • Responsive web interface"
    echo "  • Live transaction monitoring"
    echo ""
    print_status "To start the explorer:"
    echo "  cd $EXPLORER_DIR"
    echo "  ./start.sh"
    echo ""
    print_status "Or for development:"
    echo "  cd $EXPLORER_DIR"
    if command -v pnpm &> /dev/null; then
        echo "  pnpm dev"
    else
        echo "  npm run dev"
    fi
    echo ""
    print_status "The explorer will be available at: http://localhost:3000"
    echo ""
    print_warning "Make sure your Sui full node is running on port 9000 before starting the explorer!"
}

# Check if we're in the right directory or create new one
if [ ! -f "package.json" ]; then
    main "$@"
else
    print_warning "package.json already exists. Creating explorer in subdirectory..."
    mkdir -p sui-explorer-setup
    cd sui-explorer-setup
    main "$@"
fi
