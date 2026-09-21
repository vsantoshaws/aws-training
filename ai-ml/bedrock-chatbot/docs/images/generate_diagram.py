#!/usr/bin/env python3
"""Regenerate architecture-diagram.{png,svg} from this file.

Requires: `brew install graphviz` and `pip install diagrams`, then run:
    python3 docs/images/generate_diagram.py
"""
import os

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EC2, ECR
from diagrams.aws.ml import Bedrock
from diagrams.aws.network import VPC, PublicSubnet, InternetGateway
from diagrams.aws.storage import S3
from diagrams.aws.analytics import AmazonOpensearchService
from diagrams.aws.general import Users
from diagrams.aws.security import IAMRole

graph_attr = {
    "fontsize": "22",
    "fontname": "Helvetica",
    "bgcolor": "white",
    "pad": "0.4",
    "splines": "spline",
    "nodesep": "0.6",
    "ranksep": "0.9",
}

node_attr = {
    "fontsize": "13",
    "fontname": "Helvetica",
}

edge_attr = {
    "fontsize": "11",
    "fontname": "Helvetica",
}

with Diagram(
    "Metro Grand Mall Support Agent — AWS Architecture",
    filename=os.path.join(os.path.dirname(os.path.abspath(__file__)), "architecture-diagram"),
    show=False,
    direction="LR",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr,
    outformat=["png", "svg"],
):
    user = Users("Browser / User")

    with Cluster("VPC (10.20.0.0/16)"):
        igw = InternetGateway("Internet Gateway")
        with Cluster("Public Subnet"):
            ec2 = EC2("Chat UI\n(Flask + gunicorn)\n:8000")

    ecr = ECR("ECR\nStrands agent image\n(linux/arm64)")

    with Cluster("Bedrock AgentCore Runtime"):
        agent = Bedrock("Strands Agent\ncontainer")

    llm = Bedrock("Bedrock FM\n(Claude, cross-region\ninference profile)")

    with Cluster("Knowledge base stack"):
        kb = Bedrock("Knowledge Base\n(type: VECTOR)")
        oss = AmazonOpensearchService("OpenSearch Serverless\ncollection + vector index")
        s3 = S3("S3 bucket\nsample_data/ → policies/")

        kb >> Edge(label="") >> oss
        s3 >> Edge(label="embedded vectors", style="dashed") >> oss

    iam = IAMRole("IAM roles\n(chat-ui, runtime, kb)")

    user >> Edge(label="HTTP :8000") >> igw >> ec2
    ec2 >> Edge(label="boto3\ninvoke_agent_runtime()") >> agent
    ecr >> Edge(label="container image", style="dashed") >> agent
    agent >> Edge(label="ConverseStream") >> llm
    agent >> Edge(label="Retrieve") >> kb
    s3 >> Edge(label="ingestion job") >> kb
    iam >> Edge(style="dotted", color="gray") >> ec2
    iam >> Edge(style="dotted", color="gray") >> agent
    iam >> Edge(style="dotted", color="gray") >> kb

print("done")
