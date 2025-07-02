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
        status_msg, patches_msg = await asyncio.gather(
            ci_status_bot.main(session, jobs),
            gerrit_patch_count.get_patch_counts(session, tforg_query),
        )

        try:
            await send_truncated_msg(webhook, status_msg)
            await send_msg(webhook, patches_msg)
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
