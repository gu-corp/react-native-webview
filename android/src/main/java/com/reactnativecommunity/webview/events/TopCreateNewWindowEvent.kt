package com.reactnativecommunity.webview.events

import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter

/**
 * Event emitted when window.open() is called
 */
class TopCreateNewWindowEvent(viewId: Int, private val mData: WritableMap) : Event<TopShouldStartLoadWithRequestEvent>(viewId) {
  companion object {
    const val EVENT_NAME = "topCreateNewWindow"
  }

  init {
    mData.putString("navigationType", "other")
  }

  override fun getEventName(): String = EVENT_NAME

  override fun canCoalesce(): Boolean = false

  override fun getCoalescingKey(): Short = 0

  override fun dispatch(rctEventEmitter: RCTEventEmitter) =
    rctEventEmitter.receiveEvent(viewTag, EVENT_NAME, mData)
}