class PostsController < ApplicationController
  before_action :ensure_login!, only: [:create, :update, :hide, :destroy]
  before_action :set_post, only: [:show, :update, :refresh, :hide, :destroy]
  before_action :check_ownership!, only: [:update, :destroy, :hide]

  # GET /posts
  def index
    days_ago = params[:days_ago].to_i
    sort = case params[:sort]
    when 'created'
      'created_at DESC'
    when 'vote_count'
      'json_array_length(active_votes) DESC'
    when 'comment_count'
      'children DESC'
    else
      'payout_value DESC'
    end


    today = Time.zone.today.to_time

    @posts = if days_ago > 0
      Post.where('created_at >= ? AND created_at < ?', today - days_ago.days, today - (days_ago - 1).days)
    else
      Post.where('created_at >= ?', today)
    end.where(is_active: true).order(sort)
    # NOTE: DB indices on `is_active`, `payout_value` are omitted as intended as the number of records on daily posts is small

    render json: @posts
  end

  # GET /posts/@:author/:permlink
  def show
    render json: @post
  end

  # GET /posts/exists
  def exists
    result = exists?(params[:url])

    if result == 'INVALID'
      render json: { result: 'INVALID' } and return
    end

    if result
      render json: { result: 'ALREADY_EXISTS' }
    else
      render json: { result: 'OK' }
    end
  end

  # POST /posts
  def create
    @post = Post.new(post_params)

    if exists?(@post.url) # if 'INVALID' or true
      render json: { error: 'The product already exists on Steemhunt.' }, status: :unprocessable_entity and return
    end

    if @post.save
      render json: @post, status: :created
    else
      render json: { error: @post.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  # PUT /posts/@:author/:permlink
  def update
    if @post.update(post_params)
      render json: { result: 'OK' }
    else
      render json: { error: @post.errors.full_messages.first }, status: :unprocessable_entity
    end
  end

  # DELETE /posts/@:author/:permlink
  def destroy
    @post.destroy

    render json: { head: :no_content }
  end

  # PATCH /posts/refresh/@:author/:permlink
  def refresh
    if @post.update(post_refresh_params)
      render json: { result: 'OK' }
    else
      render json: { error: 'UNPROCESSABLE_ENTITY' }, status: :unprocessable_entity
    end
  end

  # PUT /hide/@:author/:permlink
  def hide
    if @post.update(is_active: !params[:hide])
      render json: { result: 'OK' }
    else
      render json: { error: 'UNPROCESSABLE_ENTITY' }, status: :unprocessable_entity
    end
  end

  private
    def set_post
      @post = Post.find_by(author: params[:author], permlink: params[:permlink])
      render_404 and return if !@post || !@post.active?
    end

    def post_params
      params.require(:post).permit(:author, :url, :title, :tagline, :description, :permlink, :is_active, tags: [],
        beneficiaries: [ :account, :weight ],
        images: [ :id, :name, :link, :width, :height, :type, :deletehash ])
    end

    def post_refresh_params
      params.require(:post).permit(:payout_value, :children, active_votes: [ :voter, :weight, :rshares, :percent, :reputation, :time ])
    end

    def search_url(uri)
      parsed = URI.parse(uri)

      return nil if parsed.host.blank? || !['http', 'https'].include?(parsed.scheme)

      host = parsed.host.gsub('www.', '')
      path = parsed.path == '/' ? '' : parsed.path

      # Google Playstore apps use parameters for different products
      return uri if host == 'play.google.com' && path == '/store/apps/details'

      "http%://%#{host}#{path}%"
    end

    def exists?(uri)
      if search = search_url(uri)
        Post.where('url LIKE ?', search).exists?  # NOTE: Check index scan
      else
        'INVALID'
      end
    end
end
