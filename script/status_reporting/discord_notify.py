#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "aiohttp~=3.12.15",
#     "discord.py~=2.6.2",
# ]
# ///

"""
Discord webhook notifier for the daily CI status.

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
import ci_status_bot
import discord
import gerrit_patch_count

DISCORD_MSG_CHAR_LIMIT = 2000


async def send_msg(webhook: discord.Webhook, msg: str) -> None:
    await webhook.send(
        msg,
        username="Jenkins daily status",
    )


async def send_truncated_msg(webhook: discord.Webhook, msg: str) -> None:
    truncated = msg
    truncated_warning = ""

    while (len(truncated) + len(truncated_warning)) > DISCORD_MSG_CHAR_LIMIT:
        truncate_len = max(truncated.rfind("\n", 0, DISCORD_MSG_CHAR_LIMIT), 0)
        truncated = truncated[:truncate_len]

        truncated_count = msg[truncate_len:].count("\n")
        truncated_warning = f"\n<{truncated_count} more lines have been truncated>"

    await send_msg(webhook, truncated + truncated_warning)


async def send_daily_status(webhook_url: str, tforg_query: str, jobs: list[str]):
    async with aiohttp.ClientSession() as session:
        webhook = discord.Webhook.from_url(webhook_url, session=session)

        # run concurrently to reduce latency between the messages
        daily_statuses, patch_totals = await asyncio.gather(
            ci_status_bot.get_daily_jobs(session, jobs),
            gerrit_patch_count.get_patch_counts(session, tforg_query),
        )
        status_msg = ci_status_bot.format_daily_status(daily_statuses)

        try:
            await send_truncated_msg(webhook, status_msg)
            await send_msg(
                webhook,
                gerrit_patch_count.format_patch_totals(patch_totals),
            )
        except discord.HTTPException as e:
            await send_msg(webhook, f"Error. Reason: {e}")
        except Exception as e:
            await send_msg(webhook, f"Error. Reason: {type(e).__name__}: {e}")
            raise e


def main():
    parser = argparse.ArgumentParser(
        description="CI daily status Discord notifier",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "discord_webhook_url",
        metavar="discord-webhook-url",
        help="the full Webhook URL that Discord provides",
    )
    gerrit_patch_count.add_gerrit_arg(parser)
    ci_status_bot.add_jobs_arg(parser)

    args = parser.parse_args()

    asyncio.run(
        send_daily_status(args.discord_webhook_url, args.tforg_gerrit_query, args.jobs)
    )


if __name__ == "__main__":
    main()
