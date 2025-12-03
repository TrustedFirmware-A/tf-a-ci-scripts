#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "aiohttp~=3.12.15",
#     "slack-sdk",
# ]
# ///

"""
Slack notifier for the daily CI status.

Installing as a notification service:
  1. Copy the timer and service files to /etc/systemd/system/.
  2. Edit the ExecStart property in /etc/systemd/system/notifier.service to
     point to this file and give it a webhook argument. Make sure to either have
     `uv` available for root or have all packages installed in a venv.
  3. run `sudo chmod 600 /etc/systemd/system/notifier.service` to keep the
     webhook secret as much as possible.
  4. run `sudo systemctl enable --now notifier.timer`.
"""

import argparse
import asyncio

import aiohttp
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

import ci_status_bot
import gerrit_patch_count


async def send_msg(client: WebClient, channel: str, msg: str) -> None:
    await asyncio.to_thread(
        client.chat_postMessage,
        channel=channel,
        text=msg,
        mrkdwn=True,
        unfurl_links=False,
        unfurl_media=False,
    )


def format_daily_status_msg(results):
    status_emoji = (
        ":green_circle:" if all(job.passed for job in results) else ":red_circle:"
    )

    if results:
        top_status = results[0]
        job_name = top_status.name
        build_link = f"<{top_status.url}|#{top_status.build_number}>"
    else:
        job_name = "Daily Status"
        build_link = ""

    more_info = (
        "_More details: "
        "<https://discord.com/channels/1106321706588577904/1407044503725932596|"
        "#tf-a-open-ci-status> on Discord._"
    )

    headline = f"{status_emoji} *{job_name}* {build_link}".strip()
    return "\n".join([headline, more_info])


async def send_daily_status(
    channel: str, token: str, tforg_query: str, jobs: list[str]
):
    async with aiohttp.ClientSession() as session:
        client = WebClient(token=token)

        # run concurrently to reduce latency between the messages
        daily_jobs, patch_totals = await asyncio.gather(
            ci_status_bot.get_daily_jobs(session, jobs),
            gerrit_patch_count.get_patch_counts(session, tforg_query),
        )

        combined_message = "\n\n".join(
            [
                format_daily_status_msg(daily_jobs),
                gerrit_patch_count.format_patch_totals(patch_totals, bullet="-"),
            ]
        )

        try:
            await send_msg(client, channel, combined_message)
        except SlackApiError as err:
            await send_msg(client, channel, f"Error. Reason: {err}")
        except Exception as err:
            await send_msg(
                client,
                channel,
                f"Error. Reason: {type(err).__name__}: {err}",
            )
            raise


def main():
    parser = argparse.ArgumentParser(
        description="CI daily status Slack notifier",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "channel",
        metavar="slack-channel-id",
        help="Slack channel ID to send notifications to.",
    )
    parser.add_argument(
        "token",
        metavar="slack-token",
        help="Slack bot token.",
    )
    gerrit_patch_count.add_gerrit_arg(parser)
    ci_status_bot.add_jobs_arg(parser)

    args = parser.parse_args()

    asyncio.run(
        send_daily_status(args.channel, args.token, args.tforg_gerrit_query, args.jobs)
    )


if __name__ == "__main__":
    main()
