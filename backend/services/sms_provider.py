from __future__ import annotations

import asyncio
import logging
from abc import ABC, abstractmethod

logger = logging.getLogger(__name__)

class SmsSendError(Exception):
    """"""

class SmsProvider(ABC):
    name: str = "abstract"

    @abstractmethod
    async def send(self,*,phone_e164:str,message:str)-> None:
        raise NotImplementedError
    

class ConsoleSmsProvider(SmsProvider):
    name = "console"

    async def send (self,*,phone_e164: str,message:str)-> None:
        logger.warning(
              "\n┌─[DEV SMS via %s]────────────────────────\n"

            "│ to:      %s\n"

            "│ message: %s\n"

            "└─────────────────────────────────────────",

            self.name,
            phone_e164,
            message.replace("\n","\n|"),

        )
        
    
class AfricasTalkingSmsProvider(SmsProvider):
    name = "africastalking"

    def __init__(self,username:str,api_key:str,sender_id:str | None) ->None:
        self._username = username
        self._api_key = api_key
        self._sender_id = sender_id

    async def send(self,*,phone_e164:str,message:str) -> None:
        try:
            import africastalking
        
        except ImportError as exc:
            raise SmsSendError(
                "africastalking SDK not installed"
            ) from exc
        # Africa's Talking validates recipients as E.164 numbers, including the
        # leading "+" (for example, +254757704448).
        recipient = phone_e164
        
        try:
            sms_service = africastalking.SMSService(
                username = self._username,
                api_key=self._api_key,
            )

            response = await asyncio.to_thread(
                sms_service.send,
                message=message,
                recipients=[recipient],
                sender_id=self._sender_id,
            )

            logger.info("AT SMS sent () to %s: %s",phone_e164,response)
        except Exception as exc:
            raise SmsSendError(f"Africa's Talking failed: {exc}") from exc


def get_sms_provider() -> SmsProvider:

    from backend.core.config import settings

    provider = (settings.SMS_PROVIDER or "console").lower().strip()

    if provider == "console":
        return ConsoleSmsProvider()
    
    if provider == "africastalking":
        username = settings.AT_USERNAME
        api_key = settings.AT_API_KEY
        sender_id = settings.AT_SENDER_ID

        if not username or not api_key:
            raise RuntimeError(
                "SMS_PROVIDER=africastalking but AT_USERNAME/ AT_API_KEY \n are missing"

            )
        
        return AfricasTalkingSmsProvider(
            username=username,
            api_key=api_key,
            sender_id=sender_id

        )
    
    raise RuntimeError(

        f"Unknown SMS_PROVIDER={provider!r}. "

        f"Expected one of: console, africastalking."

    )
