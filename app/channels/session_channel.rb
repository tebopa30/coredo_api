class SessionChannel < ApplicationCable::Channel
  def subscribed
    # クライアントが購読開始したら、このセッション専用のストリームを開く
    stream_from "session_#{params[:session_id]}"
    # stream_from "some_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
