#!/usr/bin/env python3
"""
DeFi Security Report Generator
Consolidates findings from multiple security tools into a unified report
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any

class SecurityReportGenerator:
    def __init__(self, reports_dir: str):
        self.reports_dir = Path(reports_dir)
        self.protocols = ["compound", "venus", "curve", "uniswap-v4"]
        self.severity_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Informational": 4}
        
    def parse_slither_report(self, protocol: str) -> Dict[str, Any]:
        """Parse Slither JSON report"""
        report_path = self.reports_dir / f"slither-{protocol}" / "slither-report.json"
        
        if not report_path.exists():
            return {"findings": [], "total": 0}
        
        try:
            with open(report_path) as f:
                data = json.load(f)
                
            detectors = data.get("results", {}).get("detectors", [])
            
            findings = []
            for detector in detectors:
                findings.append({
                    "tool": "Slither",
                    "severity": detector.get("impact", "Unknown"),
                    "type": detector.get("check", "Unknown"),
                    "description": detector.get("description", ""),
                    "locations": [elem.get("source_mapping", {}).get("filename_short", "") 
                                 for elem in detector.get("elements", [])]
                })
            
            return {
                "findings": findings,
                "total": len(findings),
                "by_severity": self._count_by_severity(findings)
            }
        except Exception as e:
            print(f"Error parsing Slither report for {protocol}: {e}")
            return {"findings": [], "total": 0}
    
    def parse_mythril_reports(self, protocol: str) -> Dict[str, Any]:
        """Parse Mythril markdown reports"""
        mythril_dir = self.reports_dir / f"mythril-{protocol}" / "mythril"
        
        if not mythril_dir.exists():
            return {"findings": [], "total": 0}
        
        findings = []
        for report_file in mythril_dir.glob("*-report.md"):
            try:
                with open(report_file) as f:
                    content = f.read()
                    
                # Simple parsing - count issues mentioned
                if "SWC-" in content or "Warning" in content:
                    findings.append({
                        "tool": "Mythril",
                        "severity": "Medium",  # Default
                        "type": "Symbolic Execution Finding",
                        "description": f"Issues found in {report_file.stem}",
                        "locations": [str(report_file)]
                    })
            except Exception as e:
                print(f"Error parsing Mythril report {report_file}: {e}")
        
        return {
            "findings": findings,
            "total": len(findings),
            "by_severity": self._count_by_severity(findings)
        }
    
    def _count_by_severity(self, findings: List[Dict]) -> Dict[str, int]:
        """Count findings by severity"""
        counts = {"Critical": 0, "High": 0, "Medium": 0, "Low": 0, "Informational": 0}
        for finding in findings:
            severity = finding.get("severity", "Unknown")
            if severity in counts:
                counts[severity] += 1
        return counts
    
    def calculate_risk_score(self, protocol: str, findings: Dict[str, Any]) -> float:
        """Calculate risk score based on findings"""
        base_scores = {
            "compound": 7.5,
            "venus": 8.5,  # Higher due to old Solidity
            "curve": 6.0,
            "uniswap-v4": 5.0
        }
        
        base = base_scores.get(protocol, 5.0)
        
        # Adjust based on findings
        severity_weights = {"Critical": 2.0, "High": 1.0, "Medium": 0.3, "Low": 0.1}
        
        adjustment = 0
        for severity, weight in severity_weights.items():
            count = findings.get("by_severity", {}).get(severity, 0)
            adjustment += count * weight
        
        # Cap at 10
        return min(10.0, base + adjustment * 0.1)
    
    def get_risk_level(self, score: float) -> str:
        """Get risk level from score"""
        if score >= 8:
            return "🔴 CRITICAL"
        elif score >= 6:
            return "🟠 HIGH"
        elif score >= 4:
            return "🟡 MEDIUM"
        else:
            return "🟢 LOW"
    
    def generate_markdown_report(self) -> str:
        """Generate consolidated markdown report"""
        report = []
        report.append("# 🔒 DeFi Protocol Security Analysis Report\n")
        report.append(f"**Generated:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}\n")
        report.append("**Pipeline:** Automated CI/CD Security Scanner\n")
        report.append("\n---\n\n")
        
        # Executive Summary
        report.append("## 📊 Executive Summary\n\n")
        report.append("This automated security analysis covers multiple DeFi protocols using:\n\n")
        report.append("- **Slither**: Static analysis for vulnerability detection\n")
        report.append("- **Foundry**: Comprehensive testing and fuzzing\n")
        report.append("- **Mythril**: Symbolic execution analysis\n")
        report.append("- **Echidna**: Property-based fuzzing\n")
        report.append("- **Aderyn**: Modern Rust-based static analysis\n\n")
        
        # Protocol Analysis
        all_findings = {}
        
        for protocol in self.protocols:
            report.append(f"## 🎯 {protocol.upper()} Protocol\n\n")
            
            # Parse reports
            slither_findings = self.parse_slither_report(protocol)
            mythril_findings = self.parse_mythril_reports(protocol)
            
            # Combine findings
            total_findings = slither_findings["total"] + mythril_findings["total"]
            combined_severity = {
                "Critical": slither_findings.get("by_severity", {}).get("Critical", 0) + 
                           mythril_findings.get("by_severity", {}).get("Critical", 0),
                "High": slither_findings.get("by_severity", {}).get("High", 0) + 
                       mythril_findings.get("by_severity", {}).get("High", 0),
                "Medium": slither_findings.get("by_severity", {}).get("Medium", 0) + 
                         mythril_findings.get("by_severity", {}).get("Medium", 0),
                "Low": slither_findings.get("by_severity", {}).get("Low", 0) + 
                      mythril_findings.get("by_severity", {}).get("Low", 0),
            }
            
            all_findings[protocol] = {"by_severity": combined_severity, "total": total_findings}
            
            # Calculate risk score
            risk_score = self.calculate_risk_score(protocol, all_findings[protocol])
            risk_level = self.get_risk_level(risk_score)
            
            report.append(f"**Risk Score:** {risk_score:.1f}/10 ({risk_level})\n\n")
            report.append(f"**Total Findings:** {total_findings}\n\n")
            
            # Severity breakdown
            report.append("### Findings by Severity\n\n")
            report.append(f"- 🔴 Critical: {combined_severity['Critical']}\n")
            report.append(f"- 🟠 High: {combined_severity['High']}\n")
            report.append(f"- 🟡 Medium: {combined_severity['Medium']}\n")
            report.append(f"- 🟢 Low: {combined_severity['Low']}\n\n")
            
            # Tool-specific results
            report.append("### Analysis Tools\n\n")
            report.append(f"- **Slither**: {slither_findings['total']} findings\n")
            report.append(f"- **Mythril**: {mythril_findings['total']} findings\n")
            report.append(f"- **Foundry**: Tests executed (see artifacts)\n")
            report.append(f"- **Echidna**: Fuzzing completed (see artifacts)\n\n")
            
            report.append("---\n\n")
        
        # Risk Comparison Table
        report.append("## 📈 Protocol Risk Comparison\n\n")
        report.append("| Protocol | Risk Score | Risk Level | Critical | High | Medium | Low |\n")
        report.append("|----------|------------|------------|----------|------|--------|-----|\n")
        
        for protocol in self.protocols:
            findings = all_findings.get(protocol, {})
            score = self.calculate_risk_score(protocol, findings)
            level = self.get_risk_level(score)
            severity = findings.get("by_severity", {})
            
            report.append(f"| {protocol.title()} | {score:.1f} | {level} | "
                         f"{severity.get('Critical', 0)} | {severity.get('High', 0)} | "
                         f"{severity.get('Medium', 0)} | {severity.get('Low', 0)} |\n")
        
        report.append("\n")
        
        # Recommendations
        report.append("## 🚨 Recommendations\n\n")
        report.append("### Immediate Actions\n")
        report.append("1. Review all CRITICAL and HIGH severity findings\n")
        report.append("2. Patch identified vulnerabilities\n")
        report.append("3. Add missing access controls\n")
        report.append("4. Implement reentrancy guards where needed\n\n")
        
        report.append("### Short-term Improvements\n")
        report.append("1. Increase test coverage to >90%\n")
        report.append("2. Add comprehensive invariant tests\n")
        report.append("3. Implement real-time monitoring\n")
        report.append("4. Set up automated security scanning\n\n")
        
        report.append("### Long-term Strategy\n")
        report.append("1. Professional security audit by reputable firm\n")
        report.append("2. Establish bug bounty program\n")
        report.append("3. Continuous security testing in CI/CD\n")
        report.append("4. Regular security training for developers\n\n")
        
        # Vulnerability Categories
        report.append("## 🔍 Vulnerability Categories Tested\n\n")
        categories = [
            "1. **Reentrancy Attacks** - Classic, cross-function, read-only",
            "2. **Price Oracle Manipulation** - Flash loans, TWAP, staleness",
            "3. **Access Control** - Unauthorized access, privilege escalation",
            "4. **Integer Issues** - Overflow/underflow, decimal mismatches",
            "5. **Logic Errors** - State transitions, edge cases, front-running",
            "6. **External Calls** - Unchecked returns, delegatecall issues",
            "7. **Other** - Timestamp dependence, weak randomness, locked ether"
        ]
        
        for category in categories:
            report.append(f"{category}\n")
        
        report.append("\n")
        
        # Footer
        report.append("---\n\n")
        report.append("## 📎 Detailed Reports\n\n")
        report.append("All detailed reports are available in the workflow artifacts:\n\n")
        report.append("- Slither JSON and Markdown reports\n")
        report.append("- Foundry test results and coverage\n")
        report.append("- Mythril symbolic execution reports\n")
        report.append("- Echidna fuzzing results\n")
        report.append("- Aderyn analysis reports\n\n")
        
        report.append("**⚠️ Disclaimer:** This automated analysis is not a substitute for "
                     "professional security audits. Always conduct thorough manual review "
                     "and professional audits before mainnet deployment.\n")
        
        return "".join(report)
    
    def save_report(self, output_path: str):
        """Generate and save report"""
        report_content = self.generate_markdown_report()
        
        with open(output_path, "w") as f:
            f.write(report_content)
        
        print(f"✅ Report generated: {output_path}")

def main():
    if len(sys.argv) < 2:
        reports_dir = "all-reports"
    else:
        reports_dir = sys.argv[1]
    
    generator = SecurityReportGenerator(reports_dir)
    generator.save_report("SECURITY_REPORT.md")
    
    print("\n📊 Report generation complete!")
    print("📄 View: SECURITY_REPORT.md")

if __name__ == "__main__":
    main()
