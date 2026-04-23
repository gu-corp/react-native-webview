package com.reactnativecommunity.webview.events

import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter

/**
 * Note: In Fabric, codegen derives event names from the spec (onXxx → topXxx),
 * So the native code must match with RNCWebViewNativeComponent.ts
 * Prop: onReceiveWebViewStatus
 * Event Name: topReceiveWebViewStatus
 * */
class TopRequestWebViewStatusEvent(viewId: Int, private val mEventData: WritableMap) :
  Event<TopRequestWebViewStatusEvent>(viewId) {
  companion object {
    const val EVENT_NAME = "topReceiveWebViewStatus"
  }

  override fun getEventName(): String = EVENT_NAME

  override fun canCoalesce(): Boolean = false

  override fun getCoalescingKey(): Short = 0

  override fun dispatch(rctEventEmitter: RCTEventEmitter) =
    rctEventEmitter.receiveEvent(viewTag, eventName, mEventData)

}