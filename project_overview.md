# Analysis Orchestration Engine - Project Requirements (Revised)

## 📋 Project Overview

### **Mission Statement**
Build a cloud-abstracted, scalable analysis orchestration engine that can efficiently process variable workloads including video analysis, transcription, and data correlation tasks while maintaining cost efficiency and ease of adoption.

### **Target Audience**
- **Primary**: Open source community and organizations needing flexible data processing pipelines
- **Secondary**: Research institutions and analytics teams
- **Adoption Goal**: Easy setup and contribution for DevOps engineers and data scientists

---

## 🎯 Core Requirements

### **1. Cloud Abstraction**
- **Primary Cloud**: AWS (initial implementation)
- **Architecture Pattern**: Abstract interfaces with swappable cloud provider implementations. The immediate goal is a **cloud-abstracted** architecture, not full cloud-agnosticism, to ensure a clean and modular AWS implementation that can be extended in the future.
- **Future Support**: GCP, Azure through pluggable modules
- **Implementation**: Terraform modules with provider-specific backends

### **2. Orchestration Engine**
- **Platform**: Apache Airflow with Kubernetes Executor
- **Scaling**: Dynamic pod creation for task isolation
- **API Access**: RESTful API for DAG submission and management
- **Authentication**: OAuth/OIDC integration for production security

### **3. Kubernetes Infrastructure**
- **Cluster Type**: Amazon EKS (Elastic Kubernetes Service)
- **Node Strategy**: Mixed instance types with spot pricing
- **Autoscaling**: KEDA for queue-depth based scaling + cluster autoscaler
- **Scale Range**: 0-20+ worker nodes based on demand

### **4. Compute Workload Support (Phased Approach)**
- **Phase 1 Focus**: **AWS Batch** for large-scale, containerized parallel jobs.
- **Future Support**:
  - AWS Lambda for lightweight, event-driven tasks.
  - Amazon ECS for medium-sized, long-running container workloads.
- **GPU Workloads**: Dedicated GPU node pools (g4dn/g5 instances) managed via AWS Batch.

---

## 🔧 Technical Specifications

### **Infrastructure as Code**
```yaml
Tool: Terraform >= 1.0
Modules:
  - Core EKS cluster with networking (terraform-aws-modules/eks v20.37.1)
  - Node groups (general + GPU)
  - Storage (S3 buckets + Glue database)
  - IAM roles with IRSA
  - Security groups and networking
Providers:
  - AWS Provider v5.100.0
  - Kubernetes Provider v2.37.1
  - Helm Provider v2.17.0
```

### **Container Orchestration**
```yaml
Kubernetes Version: 1.33+
Executor: KubernetesExecutor
Apache Airflow: Helm Chart v1.17.0 (Airflow 3.0+)
Auto-scaling: KEDA v2.17.2 + Cluster Autoscaler
Node Types:
  - General: t3/m5 medium/large (spot instances)
  - GPU: g4dn/g5 xlarge/2xlarge (spot instances)
```

### **Storage Architecture**
```yaml
Raw Data: S3 bucket (videos, audio, source files)
Processed Data: S3 bucket + Apache Iceberg tables
Analytics: AWS Glue catalog + Athena
Logs: S3 with lifecycle policies (30-day retention)
```

### **Security Requirements**
```yaml
Authentication: IAM Roles for Service Accounts (IRSA)
Network: Private subnets with NAT gateways
Encryption: At rest (S3, EBS) and in transit (TLS)
Access Control: Least privilege principle
Metadata Security: IMDSv2 enforcement, hop limit = 1
```

---

## 📊 Workload Types & Use Cases

### **1. Video Processing Pipeline (Phase 1 Focus)**
```yaml
Input: Video files (MP4, AVI, MOV)
Processing:
  - GPU-accelerated frame extraction
  - Scene analysis using ML models
  - Object detection and tracking
Output: Processed frames, metadata, analysis results
Compute: **AWS Batch** with GPU nodes
Storage: S3 raw → S3 processed + Iceberg tables
```

### **2. Audio Transcription Workflow**
```yaml
Input: Audio files (MP3, WAV, FLAC)
Processing:
  - NLP analysis: Sentiment, keywords, topics
Output: Transcriptions, analysis results
Compute: **AWS Batch** (GPU for NLP)
Storage: S3 → processed data + analytics tables
```

### **3. Eye Tracking Analysis**
```yaml
Input: Eye tracking data (CSV, proprietary formats)
Processing:
  - Data preprocessing and cleaning
  - Pattern analysis using ML models
Output: Insights, patterns, reports
Compute: **AWS Batch** (GPU for ML analysis)
Storage: Raw data → processed → Iceberg analytics
```

---

## 🔀 Scaling & Performance Requirements

### **Auto-scaling Triggers**
```yaml
Primary Metric: Airflow task queue depth
Scaling Thresholds:
  - General workers: > 5 queued tasks  
  - GPU workers: > 1 queued GPU task (scales from 0)
Scaling Behavior:
  - Scale up Goal: < 5 minutes (node provisioning dependent)
  - Scale down: 5-minute cooldown for general, 5-minute for GPU
  - Scale to zero: Fully supported - GPU nodes start at 0 capacity
GPU Cost Optimization:
  - Zero idle costs: GPU nodes only run when GPU tasks are queued
  - Tainted nodes: Only GPU workloads scheduled on GPU instances
  - Fast provisioning: GPU-optimized AMI for quicker startup
```

### **Performance Goals**
*Performance targets will be benchmarked and refined during development.*
```yaml
Task Startup Time Goal: < 3 minutes (general), < 6 minutes (GPU)
Throughput Goal: 100+ concurrent tasks
Availability Target: 99.5% uptime
Cost Efficiency Target: 60-80% cost savings vs. fixed infrastructure
```

### **Resource Limits**
```yaml
Maximum Nodes:
  - General: 20 nodes
  - GPU: 5 nodes
Maximum Tasks: 200+ concurrent
Queue Depth: Unlimited (managed by autoscaling)
```

---

## 🛠 Development & Operations

### **Cloud-Abstracted Interface Design**
```python
# Abstract interfaces for future cloud providers
class CloudComputeInterface(ABC):
    @abstractmethod
    def submit_job(self, job_config: Dict) -> str

class CloudStorageInterface(ABC):
    @abstractmethod
    def upload_file(self, local_path: str, remote_path: str) -> bool
```

### **Custom Operators**
```yaml
CloudComputeOperator:
  - Initial Support: AWS Batch
  - Future: AWS Lambda, Amazon ECS, Google Cloud Run, Azure Functions

CloudStorageOperator:
  - Initial Support: S3
  - Future: GCS, Azure Blob Storage

GPUKubernetesOperator:
  - GPU resource allocation (nvidia.com/gpu: 1)
  - Automatic node affinity and tolerations
  - Zero-to-scale GPU node provisioning
  - Queue: 'gpu' for automatic scaling triggers
```

### **GPU Workload Configuration**
```python
# Example GPU task configuration in Airflow DAG
gpu_task = KubernetesPodOperator(
    task_id='gpu_processing',
    queue='gpu',  # Triggers GPU node scaling from 0
    tolerations=[{
        'key': 'nvidia.com/gpu',
        'operator': 'Equal', 
        'value': 'true',
        'effect': 'NoSchedule'
    }],
    node_selector={'worker_type': 'gpu'},
    resources={
        'requests': {'nvidia.com/gpu': 1, 'memory': '4Gi'},
        'limits': {'nvidia.com/gpu': 1, 'memory': '8Gi'}
    }
)
```

### **Deployment Strategy**
```yaml
Infrastructure: Terraform apply (target 30-45 minutes)
Applications: Helm charts for Airflow + KEDA
DAG Management: API-based upload + Git integration
Monitoring: Built-in Airflow UI + optional Prometheus
```

---

## 💰 Cost Optimization Requirements

### **Spot Instance Strategy**
```yaml
Coverage: 80%+ of compute using spot instances
Diversification: Multiple instance types per node group
Fallback: On-demand instances for critical workloads
Savings Target: 60-70% vs. on-demand pricing
```

### **Resource Efficiency**
```yaml
Idle Cost: Near-zero for compute (scale-to-zero). Note: Fixed costs for EKS control plane, NAT gateways, etc. will remain.
Over-provisioning: < 20% waste through right-sizing
Utilization Target: > 70% average resource utilization
Storage Lifecycle: Automated cleanup and archiving
```

---

## 🔒 Security & Compliance

### **Identity & Access Management**
```yaml
Service Accounts: One per application/workload
IAM Policies: Least privilege access
Cross-Service Access: IRSA for AWS service integration
Authentication: OAuth/OIDC for human users
```

### **Network Security**
```yaml
Cluster Access: Private API endpoint preferred
Node Network: Private subnets only
Internet Access: Through NAT gateways
Load Balancer: Network Load Balancer for web UI
```

### **Data Protection**
```yaml
Encryption at Rest: All S3 buckets and EBS volumes
Encryption in Transit: TLS 1.2+ for all communications
Secrets Management: Kubernetes secrets + AWS Secrets Manager
Audit Logging: CloudTrail + EKS audit logs
```

---

## 📈 Monitoring & Observability

### **Metrics & Alerting**
```yaml
Infrastructure: Node health, resource utilization
Application: Task success/failure rates, queue depth
Performance: Task execution times, scaling latency
Cost: Spend tracking, resource efficiency metrics
```

### **Logging Strategy**
```yaml
Application Logs: S3 remote logging for Airflow
Infrastructure Logs: CloudWatch for EKS components
Audit Logs: CloudTrail for API access
Retention: 30 days for logs, 1 year for audit
```

---

## 🚀 Success Criteria

### **Functional Requirements**
- ✅ Process the **video processing workload** successfully using AWS Batch
- ✅ Scale from 0 to capacity based on queue depth
- ✅ Support API-based DAG management
- ✅ Maintain 99.5% availability during normal operations

### **Non-Functional Requirements**
- ✅ Highly automated deployment process (target < 60 minutes)
- ✅ Achieve 60%+ cost savings vs. fixed infrastructure
- ✅ Support 100+ concurrent tasks
- ✅ Enable easy contribution by open source community

### **Adoption Goals**
- ✅ Documentation enables deployment by a DevOps engineer
- ✅ Example workflows demonstrate core capabilities
- ✅ Modular design allows selective component adoption
- ✅ Clear path for adding new compute backends and cloud providers

---

## 🛣 Future Roadmap

### **Phase 1 (Current): AWS Foundation**
- **Goal**: Prove the core architecture with a single compute backend and primary workload.
- **Tasks**:
  - Complete EKS infrastructure via Terraform.
  - Implement Airflow with a **CloudComputeOperator for AWS Batch**.
  - Implement basic auto-scaling with KEDA.
  - Deliver a robust **video processing pipeline** as the primary example.
  - Create initial documentation for DevOps and Data Scientist personas.

### **Phase 2: Expand Workload & Cloud Support**
- **Goal**: Broaden workload capabilities and begin multi-cloud expansion.
- **Tasks**:
  - Add support for **AWS Lambda and ECS** to the `CloudComputeOperator`.
  - Begin GCP implementation (GKE, Cloud Functions, GCS).
  - Enhance monitoring and observability with detailed dashboards.

### **Phase 3: Advanced Features & Multi-Cloud**
- **Goal**: Introduce advanced processing and achieve broader cloud support.
- **Tasks**:
  - Complete Azure implementation (AKS, Functions, Blob Storage).
  - Support ML model deployment and serving.
  - Introduce real-time streaming data processing capabilities.
  - Implement advanced cost optimization algorithms.

### **Phase 4: Ecosystem Integration**
- **Goal**: Mature the project into a rich ecosystem.
- **Tasks**:
  - Data catalog integration (Apache Atlas, DataHub).
  - CI/CD pipeline templates for users.
  - Marketplace for community-contributed operators.
  - Explore managed service offerings.

---

## 📚 Documentation Requirements

### **DevOps Engineer Documentation**
- Quick start guide (0 to running infrastructure)
- Architecture deep dive
- Deployment automation scripts
- Security best practices guide
- Monitoring and alerting setup
- Backup and disaster recovery

### **Data Scientist / Analyst Documentation**
- Quick start guide (writing and running your first DAG)
- Custom operator development guide
- Cloud provider implementation guide
- API reference documentation
- Troubleshooting and FAQ

---

## ⚡ Getting Started Checklist

### **Prerequisites**
- [ ] AWS CLI configured with admin permissions
- [ ] Terraform >= 1.0 installed
- [ ] kubectl and helm installed
- [ ] Docker (for custom image builds)

### **Deployment Steps**
1. [ ] Clone repository and configure variables
2. [ ] Deploy infrastructure with Terraform
3. [ ] Install Airflow and KEDA with Helm
4. [ ] Configure authentication and access
5. [ ] Deploy example video processing workflow
6. [ ] Verify scaling and monitoring

### **Post-Deployment**
- [ ] Run example DAGs to verify functionality
- [ ] Monitor auto-scaling behavior
- [ ] Set up alerting and notifications
- [ ] Plan custom workload development

---

*This project aims to democratize advanced data processing capabilities while maintaining enterprise-grade security, reliability, and cost efficiency.*
