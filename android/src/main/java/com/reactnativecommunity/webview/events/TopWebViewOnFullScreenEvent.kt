package com.reactnativecommunity.webview.events

import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event
import com.facebook.react.uimanager.events.RCTEventEmitter

/**
 * Note: In Fabric, codegen derives event names from the spec (onXxx → topXxx),
 * So the native code must match with RNCWebViewNativeComponent.ts
 * Prop: onVideoFullScreen
 * Event Name: topVideoFullScreen
 * */
/**
 * Event emitted when loading has started
 */
class TopWebViewOnFullScreenEvent(viewId: Int, private val mEventData: WritableMap) :
  Event<TopWebViewOnFullScreenEvent>(viewId) {
  companion object {
    const val EVENT_NAME = "topVideoFullScreen"
  }

  override fun getEventName(): String = EVENT_NAME

  override fun canCoalesce(): Boolean = false

  override fun getCoalescingKey(): Short = 0

  override fun dispatch(rctEventEmitter: RCTEventEmitter) =
    rctEventEmitter.receiveEvent(viewTag, eventName, mEventData)
}
