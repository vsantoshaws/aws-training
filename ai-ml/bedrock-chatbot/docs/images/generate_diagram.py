#!/usr/bin/env python3
"""Regenerate architecture-diagram.{png,svg} from this file.

Requires: `brew install graphviz` and `pip install diagrams`, then run:
    python3 docs/images/generate_diagram.py
"""
import os

from diagrams import Diagram, Cluster, Edge
from diagrams.aws.compute import EC2, ECR
from diagrams.aws.ml import Bedrock
from diagrams.aws.network import InternetGateway
from diagrams.aws.storage import S3
from diagrams.aws.analytics import AmazonOpensearchService
from diagrams.aws.general import Users

FLOW = "#5A6B7C"
IMAGE = "#D86613"

graph_attr = {
    "fontsize": "22",
    "fontname": "Helvetica",
    "bgcolor": "white",
    "pad": "0.4",
    "splines": "ortho",
    "nodesep": "1.0",
    "ranksep": "0.9",
}

node_attr = {
    "fontsize": "13",
    "fontname": "Helvetica",
}

edge_attr = {
    "fontsize": "11",
    "fontname": "Helvetica",
    "penwidth": "1.4",
}

with Diagram(
    "Metro Grand Mall Support Agent — AWS Architecture",
    filename=os.path.join(os.path.dirname(os.path.abspath(__file__)), "architecture-diagram"),
    show=False,
    direction="TB",
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
        igw >> Edge(color=FLOW) >> ec2

    with Cluster("Bedrock AgentCore Runtime"):
        ecr = ECR("ECR\nStrands agent image\n(linux/arm64)")
        agent = Bedrock("Strands Agent\ncontainer")
        ecr >> Edge(label="container image", style="dashed", color=IMAGE) >> agent

    llm = Bedrock("Bedrock FM\n(Claude, cross-region\ninference profile)")

    with Cluster("Knowledge base stack"):
        kb = Bedrock("Knowledge Base\n(type: VECTOR)")
        s3 = S3("S3 bucket\nsample_data/ → policies/")
        oss = AmazonOpensearchService("OpenSearch Serverless\ncollection + vector index")

        s3 >> Edge(label="ingestion job", color=FLOW) >> kb
        kb >> Edge(color=FLOW) >> oss
        s3 >> Edge(label="embedded vectors", style="dashed", color=IMAGE) >> oss

    user >> Edge(label="HTTP :8000", color=FLOW) >> igw
    ec2 >> Edge(label="boto3 invoke_agent_runtime()", color=FLOW) >> agent
    agent >> Edge(label="ConverseStream", color=FLOW, tailport="sw") >> llm
    agent >> Edge(label="Retrieve", color=FLOW, tailport="se") >> kb

print("done")
