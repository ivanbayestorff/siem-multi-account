#!/var/ossec/framework/python/bin/python3

import json
import os
import sys

import boto3

CONFIG = os.path.join(os.path.dirname(os.path.realpath(__file__)), "custom-sns.json")


def main(alert_path):
    with open(CONFIG) as f:
        config = json.load(f)
    with open(alert_path) as f:
        alert = json.load(f)

    rule = alert.get("rule", {})
    mitre = rule.get("mitre", {})
    technique = ", ".join(mitre.get("id", [])) or "-"
    aws = alert.get("data", {}).get("aws", {})

    if aws:
        accounts = {a["id"]: a["name"] for a in config["accounts"]}
        account = aws.get("recipientAccountId", "-")
        source = accounts.get(account, account)
        details = [
            ("Account", source),
            ("Actor", aws.get("userIdentity", {}).get("arn", "-")),
            ("Event", f"{aws.get('eventName', '-')} ({aws.get('eventSource', '-')})"),
            ("Source IP", aws.get("sourceIPAddress", "-")),
        ]
    else:
        source = alert.get("agent", {}).get("name", "-")
        syscheck = alert.get("syscheck", {})
        details = [
            ("Agent", source),
            ("File", syscheck.get("path", "-")),
            ("Change", syscheck.get("event", "-")),
        ]

    fields = [
        ("Rule", f"{rule.get('id')} (level {rule.get('level')}) {rule.get('description')}"),
        ("MITRE", f"{technique} {', '.join(mitre.get('technique', []))}"),
        *details,
        ("Time", alert.get("timestamp", "-")),
    ]
    
    subject = f"[Wazuh] {technique} - {rule.get('description', 'alert')} ({source})"
    boto3.client("sns", region_name=config["region"]).publish(
        TopicArn=config["topic_arn"],
        Subject=subject.encode("ascii", "ignore").decode()[:99],
        Message="\n".join(f"{name + ':':<11}{value}" for name, value in fields),
    )


if __name__ == "__main__":
    main(sys.argv[1])
