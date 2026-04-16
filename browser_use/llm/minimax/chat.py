"""
MiniMax API adapter for browser-use.
"""

import json
import os
import re
from dataclasses import dataclass
from typing import Any, TypeVar, overload

from openai import AsyncOpenAI
from openai.types.chat.chat_completion import ChatCompletion
from pydantic import BaseModel

from browser_use.llm.exceptions import ModelProviderError
from browser_use.llm.messages import BaseMessage
from browser_use.llm.openai.chat import ChatOpenAI
from browser_use.llm.openai.serializer import OpenAIMessageSerializer
from browser_use.llm.views import ChatInvokeCompletion, ChatInvokeUsage

T = TypeVar('T', bound=BaseModel)


def filter_thinking_tags(content: str) -> str:
	if not content:
		return content
	filtered = re.sub(r'<think>.*?</think>', '', content, flags=re.DOTALL)
	filtered = re.sub(r'\n\s*\n', '\n', filtered)
	return filtered.strip()


@dataclass
class ChatMiniMax(ChatOpenAI):
	def __post_init__(self):
		if self.base_url is None:
			self.base_url = 'https://api.minimax.chat/v1'
		if self.api_key is None:
			self.api_key = os.getenv('MINIMAX_API_KEY')

	def get_client(self) -> AsyncOpenAI:
		params = self._get_client_params()
		params.pop('reasoning_effort', None)
		return AsyncOpenAI(**params)

	@property
	def provider(self) -> str:
		return 'minimax'

	@overload
	async def ainvoke(
		self, messages: list[BaseMessage], output_format: None = None, **kwargs: Any
	) -> ChatInvokeCompletion[str]: ...

	@overload
	async def ainvoke(self, messages: list[BaseMessage], output_format: type[T], **kwargs: Any) -> ChatInvokeCompletion[T]: ...

	async def ainvoke(
		self, messages: list[BaseMessage], output_format: type[T] | None = None, **kwargs: Any
	) -> ChatInvokeCompletion[T] | ChatInvokeCompletion[str]:
		try:
			response = await self._ainvoke_impl(messages, output_format, **kwargs)
			return response
		except Exception as e:
			raise ModelProviderError(message=str(e), model=self.name) from e

	async def _ainvoke_impl(
		self, messages: list[BaseMessage], output_format: type[T] | None = None, **kwargs: Any
	) -> ChatInvokeCompletion[T] | ChatInvokeCompletion[str]:
		openai_messages = OpenAIMessageSerializer.serialize_messages(messages)

		model_params: dict[str, Any] = {}

		if self.temperature is not None:
			model_params['temperature'] = self.temperature
		if self.frequency_penalty is not None:
			model_params['frequency_penalty'] = self.frequency_penalty
		if self.max_completion_tokens is not None:
			model_params['max_tokens'] = self.max_completion_tokens
		if self.top_p is not None:
			model_params['top_p'] = self.top_p

		try:
			if output_format is None:
				response = await self.get_client().chat.completions.create(
					model=self.model,
					messages=openai_messages,
					**model_params,
				)

				choice = response.choices[0] if response.choices else None
				if choice is None:
					raise ModelProviderError(message='Invalid response: missing choices', status_code=502, model=self.name)

				content = choice.message.content or ''
				filtered = filter_thinking_tags(content)
				usage = self._get_usage(response)

				return ChatInvokeCompletion(
					completion=filtered,
					usage=usage,
					stop_reason=choice.finish_reason or 'stop',
				)
			else:
				response = await self.get_client().chat.completions.create(
					model=self.model,
					messages=openai_messages,
					response_format={'type': 'json_object'},
					**model_params,
				)

				choice = response.choices[0] if response.choices else None
				if choice is None:
					raise ModelProviderError(message='Invalid response: missing choices', status_code=502, model=self.name)

				content = choice.message.content or '{}'
				filtered = filter_thinking_tags(content)
				cleaned = self._clean_json(filtered)

				try:
					parsed = json.loads(cleaned)
					validated = output_format.model_validate(parsed)
					usage = self._get_usage(response)
					return ChatInvokeCompletion(
						completion=validated,
						usage=usage,
						stop_reason=choice.finish_reason or 'stop',
					)
				except json.JSONDecodeError as e:
					raise ModelProviderError(message=f'Invalid JSON: {str(e)}', status_code=500, model=self.name)

		except ModelProviderError:
			raise
		except Exception as e:
			raise ModelProviderError(message=str(e), model=self.name)

	def _get_usage(self, response: ChatCompletion) -> ChatInvokeUsage | None:
		if response.usage is not None:
			cached_tokens = None
			if response.usage.prompt_tokens_details:
				cached_tokens = getattr(response.usage.prompt_tokens_details, 'cached_tokens', None)

			return ChatInvokeUsage(
				prompt_tokens=response.usage.prompt_tokens or 0,
				prompt_cached_tokens=cached_tokens,
				prompt_cache_creation_tokens=None,
				prompt_image_tokens=None,
				completion_tokens=response.usage.completion_tokens or 0,
				total_tokens=response.usage.total_tokens or 0,
			)
		return None

	def _clean_json(self, content: str) -> str:
		cleaned = content.strip()

		if cleaned.startswith('```'):
			lines = cleaned.split('\n')
			if lines[0].startswith('```'):
				lines = lines[1:]
			if lines and lines[-1].strip() == '```':
				lines = lines[:-1]
			cleaned = '\n'.join(lines).strip()

		json_match = re.search(r'\{.*\}', cleaned, re.DOTALL)
		if json_match:
			return json_match.group()

		return cleaned
